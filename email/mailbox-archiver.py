#!/usr/bin/env python3
"""
--------------------------------------------------------------------------
Program     : mailbox-archiver.py
Version     : v1.0-STABLE-2026-01-30
Description : IMAP Email Archiving and Old Folder Deletion Script
Syntax      : python3 mailbox-archiver.py (--dry-run)
Author      : Andrew (andrew@devnull.uk)
--------------------------------------------------------------------------
"""

import argparse
import email
import imaplib
import re
from datetime import datetime, timedelta
from email.header import decode_header

import dateutil.parser

VERSION = "v1.0-STABLE"
IMAP_SERVER = ""
IMAP_PORT = 993
IMAP_USERNAME = ""
IMAP_PASSWORD = ""

USE_SSL = True
FOLDERS = {
    "inbox": "INBOX",  # Check exact name via list_folders() output
    "archive": "Archive",
    "base_archive_path": "Archive",  # Base for yearly subfolders (e.g., Archive.2023/)
}
FORCE_DELIMITER = "."
MAX_VALID_YEAR = datetime.now().year
MAX_KEEP_YEARS = 30
DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR = MAX_VALID_YEAR - MAX_KEEP_YEARS


def parse_args():
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--dry-run", action="store_true", help="Print actions without executing them."
    )
    return parser.parse_args()


def connect_imap(dry_run=False):
    """Connect to IMAP server."""
    if dry_run:
        print("Dry run: Would connect to IMAP server.")
        return None
    try:
        imap = (
            imaplib.IMAP4_SSL(IMAP_SERVER, IMAP_PORT)
            if USE_SSL
            else imaplib.IMAP4(IMAP_SERVER, IMAP_PORT)
        )
        imap.login(IMAP_USERNAME, IMAP_PASSWORD)
        return imap
    except Exception as e:
        print(f"Connection failed: {e}")
        exit(1)


def list_folders(imap):
    """List available folders and return folders with delimiter."""
    if not imap:
        print("Dry run: Would list available folders.")
        return [("INBOX", "."), ("Archive", "."), ("Sent", ".")]  # Mock for dry run
    try:
        result, data = imap.list()
        if result != "OK":
            print(f"Failed to list folders: {data}")
            return []
        folders = []
        print("Available folders:")
        for folder in data:
            if not folder:
                continue
            folder_str = folder.decode("utf-8", errors="ignore")
            match = re.search(r'\((.*?)\)\s*"([^"]*)"\s+(\S+)', folder_str)
            if match:
                flags, delimiter, folder_name = match.groups()
                folder_name = folder_name.strip('"')
                print(
                    f" - {folder_name} (Delimiter: '{delimiter or 'None'}', Flags: {flags})"
                )
                folders.append((folder_name, delimiter or "."))
            else:
                print(f" - Unparseable folder entry: {folder_str}")
        return folders
    except Exception as e:
        print(f"Error listing folders: {e}")
        return []


def create_folder(imap, folder_name, delimiter, dry_run=False):
    """Create folder if it doesn't exist."""
    if dry_run:
        print(f"Dry run: Would create folder: {folder_name}")
        return True
    try:
        result, data = imap.list()
        folder_exists = any(folder_name.encode("utf-8") in f for f in data)
        if not folder_exists:
            result = imap.create(folder_name)
            if result[0] == "OK":
                print(f"Created folder: {folder_name}")
            else:
                print(f"Failed to create folder: {folder_name}: {result[1]}")
                # Try without trailing slash if it fails
                if "/" in folder_name and "Invalid mailbox name" in str(result[1]):
                    fallback_folder = folder_name.rstrip("/")
                    print(f"Retrying without trailing slash: {fallback_folder}")
                    result = imap.create(fallback_folder)
                    if result[0] == "OK":
                        print(f"Created fallback folder: {fallback_folder}")
                        return True
                    print(
                        f"Failed to create fallback folder: {fallback_folder}: {result[1]}"
                    )
                    return False
        return True
    except Exception as e:
        print(f"Error creating folder {folder_name}: {e}")
        return False


def get_email_date(imap, msg_id, folder, dry_run=False):
    """Fetch email date and subject, handling non-UTF-8 headers."""
    if dry_run:
        print(f"Dry run: Would fetch date for message {msg_id} in {folder}")
        return datetime.now() - timedelta(days=730)  # Mock date for dry run
    try:
        imap.select(folder)
        result, data = imap.fetch(msg_id, "(RFC822.HEADER)")
        if result != "OK":
            print(f"Failed to fetch headers for message {msg_id} in {folder}")
            return None
        try:
            msg = email.message_from_bytes(data[0][1])
        except UnicodeDecodeError as e:
            print(f"Unicode decode error for message {msg_id} in {folder}: {e}")
            print(f"Raw headers: {data[0][1]}")
            return None
        date_str = msg.get("Date")
        subject = msg.get("Subject", "")
        sender = msg.get("From", "")
        # Decode headers with fallback to latin1
        try:
            subject_decoded = decode_header(subject)[0][0]
            subject = (
                subject_decoded.decode()
                if isinstance(subject_decoded, bytes)
                else subject_decoded or "No Subject"
            )
        except (UnicodeDecodeError, TypeError) as e:
            print(f"Failed to decode Subject for message {msg_id}: {e}")
            subject = (
                subject.decode("latin1", errors="ignore")
                if isinstance(subject, bytes)
                else subject
            )
        try:
            sender_decoded = decode_header(sender)[0][0]
            sender = (
                sender_decoded.decode()
                if isinstance(sender_decoded, bytes)
                else sender_decoded or "No Sender"
            )
        except (UnicodeDecodeError, TypeError) as e:
            print(f"Failed to decode From for message {msg_id}: {e}")
            sender = (
                sender.decode("latin1", errors="ignore")
                if isinstance(sender, bytes)
                else sender
            )
        if not date_str:
            print(
                f"No date header for message {msg_id}, subject: {subject}, sender: {sender}"
            )
            return None
        try:
            parsed_date = dateutil.parser.parse(date_str).replace(tzinfo=None)
            print(
                f"Message {msg_id} date: {date_str}, subject: {subject}, sender: {sender}"
            )
            if parsed_date.year > MAX_VALID_YEAR:
                print(f"Invalid year {parsed_date.year} for message {msg_id}")
                return None
            return parsed_date
        except Exception as e:
            print(
                f"Failed to parse date for message {msg_id}, subject: {subject}, sender: {sender}: {e}"
            )
            return None
    except Exception as e:
        print(f"Error fetching date for message {msg_id} in {folder}: {e}")
        return None


def move_emails(imap, folder, search_criteria, destination, delimiter, dry_run=False):
    """Move emails matching criteria to destination folder."""
    if dry_run:
        print(f"Dry run: Would select folder {folder} and search for {search_criteria}")
        print(f"Dry run: Would process mock emails in {folder}")
        mock_date = datetime.now() - timedelta(days=730)
        mock_year = mock_date.year
        mock_dest = (
            f"{FOLDERS['base_archive_path']}{delimiter}{mock_year}"
            if folder == FOLDERS["archive"]
            else destination
        )
        print(f"Dry run: Would move mock message from {folder} to {mock_dest}")
        return
    try:
        result = imap.select(folder)
        if result[0] != "OK":
            print(f"Failed to select folder {folder}: {result[1]}")
            return
        result, data = imap.search(None, search_criteria)
        if result != "OK":
            print(f"Search failed in {folder}: {result[1]}")
            return
        msg_ids = data[0].split()
        if not msg_ids:
            print(f"No emails found in {folder} for {search_criteria}")
            return

        for msg_id in msg_ids:
            email_date = get_email_date(imap, msg_id, folder, dry_run)
            if not email_date:
                continue
            if folder == FOLDERS["archive"]:
                year = email_date.year
                dest_folder = f"{FOLDERS['base_archive_path']}{delimiter}{year}"
                if not create_folder(imap, dest_folder, delimiter, dry_run):
                    fallback_folder = f"{FOLDERS['base_archive_path']}{delimiter}{year}"
                    if not create_folder(imap, fallback_folder, delimiter, dry_run):
                        print(
                            f"Skipping move for message {msg_id} due to folder creation failure"
                        )
                        continue
                    dest_folder = fallback_folder
            else:
                dest_folder = destination
            if dry_run:
                print(
                    f"Dry run: Would move message {msg_id} from {folder} to {dest_folder}"
                )
                print(f"Dry run: Would mark message {msg_id} for deletion")
                continue
            result = imap.copy(msg_id, dest_folder)
            if result[0] == "OK":
                imap.store(msg_id, "+FLAGS", "\\Deleted")
                print(f"Moved message {msg_id} from {folder} to {dest_folder}")
            else:
                print(f"Failed to move message {msg_id} to {dest_folder}: {result[1]}")
        if not dry_run:
            imap.expunge()
    except Exception as e:
        print(f"Error in move_emails for {folder}: {e}")


def delete_old_archive_folders(imap, year_threshold, delimiter, dry_run=False):
    """Delete yearly archive folders older than the specified year_threshold."""
    if dry_run:
        print(f"Dry run: Would delete archive folders before {year_threshold}.")
        return

    try:
        print(f"Listing folders to find archives to delete before {year_threshold}...")
        # Get all folders
        result, data = imap.list()
        if result != "OK":
            print(f"Failed to list folders: {data}")
            return

        archive_base = FOLDERS["base_archive_path"]
        # Pattern to match folders like "Archive.YYYY"
        pattern = re.compile(
            rf"^{re.escape(archive_base)}{re.escape(delimiter)}(\d{{4}})\W?$"
        )

        for folder_entry in data:
            if not folder_entry:
                continue
            folder_str = folder_entry.decode("utf-8", errors="ignore")
            match = re.search(r'\((.*?)\)\s*"([^"]*)"\s+(\S+)', folder_str)
            if match:
                flags, _, folder_name = match.groups()
                folder_name = folder_name.strip('"')

                folder_match = pattern.match(folder_name)
                if folder_match:
                    folder_year = int(folder_match.group(1))
                    if folder_year < year_threshold:
                        print(f"Found old archive folder to delete: {folder_name}")
                        try:
                            # Before deleting, select the folder and expunge to ensure it's empty
                            # Some IMAP servers require folders to be empty before deletion
                            print(
                                f"Selecting and expunging folder '{folder_name}' before deletion..."
                            )
                            imap.select(folder_name)
                            imap.expunge()
                            imap.close()

                            result = imap.delete(folder_name)
                            if result[0] == "OK":
                                print(f"Deleted folder: {folder_name}")
                            else:
                                print(
                                    f"Failed to delete folder {folder_name}: {result[1]}"
                                )
                        except Exception as e:
                            print(f"Error deleting folder {folder_name}: {e}")
    except Exception as e:
        print(f"An error occurred while deleting old archive folders: {e}")


def main():
    print(f"{VERSION} - Automate archiving and deletion tasks for IMAP folders.\n")
    args = parse_args()
    dry_run = args.dry_run

    # Connect IMAP
    imap = connect_imap(dry_run)

    # List IMAP folders and determine delimiter
    folders = list_folders(imap)
    delimiter = FORCE_DELIMITER or "/"  # Use forced delimiter for ProtonMail
    if not FORCE_DELIMITER:
        for folder_name, delim in folders:
            if folder_name in [FOLDERS["inbox"], FOLDERS["archive"]]:
                delimiter = delim
                break
    print(f"Using delimiter: '{delimiter}'")

    # Create Archive folder if it doesn't exist
    if not create_folder(imap, FOLDERS["archive"], delimiter, dry_run):
        print("Cannot proceed without Archive folder")
        if not dry_run:
            imap.logout()
        exit(1)

    # Calculate date thresholds
    one_year_ago = (datetime.now() - timedelta(days=365)).strftime("%d-%b-%Y")
    two_years_ago = (datetime.now() - timedelta(days=730)).strftime("%d-%b-%Y")

    # Rule 1: Inbox -> Archive (older than 1 year)
    print("Archiving Inbox emails older than 1 year...")
    move_emails(
        imap,
        FOLDERS["inbox"],
        f"BEFORE {one_year_ago}",
        FOLDERS["archive"],
        delimiter,
        dry_run,
    )

    # Rule 2: Archive -> Yearly subfolders (older than 2 years)
    print("Archiving Archive emails older than 2 years...")
    move_emails(
        imap, FOLDERS["archive"], f"BEFORE {two_years_ago}", None, delimiter, dry_run
    )

    # Rule 3: Check if we need to delete old archive folders
    if DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR is not None:
        if not isinstance(DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR, int):
            print("Error: DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR must be an integer year.")
        else:
            print(
                f"Initiating deletion of archive folders before {DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR}..."
            )
            delete_old_archive_folders(
                imap, DELETE_ARCHIVE_FOLDERS_BEFORE_YEAR, delimiter, dry_run
            )
            print("Old folder deletion process complete.")

    # Final Cleanup
    if not dry_run and imap:
        try:
            imap.close()
        except imaplib.IMAP4.error:
            # Ignore error if no folder is selected
            pass
        imap.logout()


if __name__ == "__main__":
    main()
