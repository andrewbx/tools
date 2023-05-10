#!/usr/bin/perl
#--------------------------------------------------------------------------
# Program     : zdtool.pl
# Version     : v1.1.9-STABLE-2018-08-05
# Description : Retrieve Zendesk ticket information.
# Syntax      : zdtool.pl <option>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

use strict;
use warnings;
use JSON qw(encode_json decode_json);
use Time::Piece;
use LWP::UserAgent;
use MIME::Base64;
use Getopt::Long qw/:config no_ignore_case/;
use Class::Struct;
use Data::Dumper;

binmode(STDOUT, ":encoding(UTF-8)");

our $VERSION = "v1.1.9-STABLE";
our $RELEASE = "ZendTOOL $VERSION";
our $CONFIG = "$ENV{'HOME'}/.zdtool";

our $UST_FORM = 654321;
our $RAL_FORM = 123456;
our $ZEN_GROUP = "123456789";
our $CHR_LIMIT = 60;

our $ZEN_URL = "https://company.zendesk.com/api/v2";
our $RAL_URL = "https://rally1.rallydev.com/slm/webservice/v2.0";
our $RAL_KEY = "<API_KEY>"; # Generic Rally Read-only API Key.

if (not -f $CONFIG) {
	warn "\nError - Configuration file not found.\n";
	help_config();
}

my $ZEN_API_AUTH = config_parse($CONFIG, "zendesk_username", "zendesk_password");

my $defect_url;

@ARGV or help();

struct rally_fields => {
	eta		=> '$',
	ninebox		=> '$',
	schedule_state	=> '$',
	defstate	=> '$',
	formatted_id	=> '$',
	defect_url	=> '$',
	sync_status	=> '$',
	sync_action	=> '$',
        status		=> '$',
};

{
	my (%args);

	GetOptions(
		'get_queue_statistics'		=> \$args{get_queue_statistics},
		'get_user_statistics=s'		=> \$args{get_user_statistics},
		'get_active_tickets=s'		=> \$args{get_active_tickets},
		'get_rally_tickets=s'		=> \$args{get_rally_tickets},
		'get_backlog_tickets=s'		=> \$args{get_backlog_tickets},
		'get_unassigned_tickets'	=> \$args{get_unassigned_tickets},
		'get_linked_tickets=i'		=> \$args{get_linked_tickets},
		'get_rally_status=i'		=> \$args{get_rally_status},
		'get_ticket_info=i'		=> \$args{get_ticket_info},
		'sync_linked_tickets=s'		=> \$args{sync_linked_tickets},
		'sync_rally_ticket=i'		=> \$args{sync_rally_ticket},
		'send_eta_response=i'		=> \$args{send_eta_response},
		'send_initial_response=i'	=> \$args{send_initial_response},
		'send_onit_response=i'		=> \$args{send_onit_response},
		'help'				=> \$args{help},
		'version'			=> \$args{version}
	) or help();

	if ($args{help}) {
		exit help();
	}

	if ($args{version}) {
		get_month();
		exit print ("$RELEASE\n");
	}

	if ($args{get_unassigned_tickets}) {
		get_unassigned_tickets();
	}

        if ($args{get_active_tickets}) {
		get_active_tickets($args{get_active_tickets});
        }

	if ($args{get_rally_tickets}) {
		get_rally_tickets($args{get_rally_tickets});
	}

	if ($args{get_backlog_tickets}) {
		get_backlog_tickets($args{get_backlog_tickets});
	}

	if ($args{get_linked_tickets}) {
		get_linked_tickets($args{get_linked_tickets});
	}

	if ($args{get_rally_status}) {
		get_rally_status($args{get_rally_status});
	}

	if ($args{get_ticket_info}) {
		get_ticket_info($args{get_ticket_info});
	}

	if ($args{get_queue_statistics}) {
		get_statistics();
	}

	if ($args{get_user_statistics}) {
		get_statistics($args{get_user_statistics});
	}

	if ($args{sync_rally_ticket}) {
		sync_rally_ticket($args{sync_rally_ticket});
	}

	if ($args{sync_linked_tickets}) {
		sync_linked_tickets($args{sync_linked_tickets});
	}

	if ($args{send_eta_response}) {
		send_eta_response($args{send_eta_response});
	}

	if ($args{send_initial_response}) {
		send_initial_response($args{send_initial_response});
	}

	if ($args{send_onit_response}) {
		send_onit_response($args{send_onit_response});
	}
}

sub help
{
	$0 =~ s{.*/}{};
	printf("
\033[1m$RELEASE\033[0m - Retrieve Zendesk ticket information.

\033[1mUsage:\033[0m
  $0 --get_queue_statistics
  $0 --get_user_statistics	<\"assignee name\", me, or email>
  $0 --get_active_tickets	<\"assignee name\", me, or email>
  $0 --get_rally_tickets  	<\"assignee name\", me, or email>
  $0 --get_backlog_tickets	<\"assignee name\", me, or email>
  $0 --get_unassigned_tickets
  $0 --get_linked_tickets	<ticket id>
  $0 --get_rally_status  	<ticket id>
  $0 --get_ticket_info		<ticket id>
  $0 --sync_linked_tickets	<\"assignee name\", me, or email>
  $0 --sync_rally_ticket 	<ticket id>
  $0 --send_eta_response 	<ticket id>
  $0 --send_initial_response	<ticket id>
  $0 --send_onit_response	<ticket id>

\033[1mOptions:\033[0m
  --get_queue_statistics		Get Team Queue Statistics.
  --get_user_statistics			Get Tean User Statistics.
  --get_active_tickets			Get List of Active Tickets for a User.
  --get_rally_tickets			Get List of Rally Tickets for a User.
  --get_backlog_tickets			Get List of Tickets at BackLog Stage 3.
  --get_unassigned_tickets		Get List of Unassigned Tickets in the Queue.
  --get_linked_tickets			Get List of Linked Incidents for a Problem Ticket ID.
  --get_rally_status			Get Rally Defect Status for Ticket ID.
  --get_ticket_info			Get Details of a Ticket by ID.
  --sync_linked_tickets			Sync Linked Tickets with Problem Case for a User.
  --sync_rally_ticket			Sync Rally Ticket Status for a Ticket ID.
  --send_eta_response			Send Response back to Customer for Assigned ETA.
  --send_initial_response		Send Initial Response to Customer for Unassigned Case.
  --send_onit_response			Send Currently Working On It Response to Customer.
  --help				Print this help information.
  --version				Print version.
");

	exit;
}

sub help_config
{
        printf("
The tool makes API calls using the credentials in $CONFIG.

File Format:

zendesk_username=<ZENDESK_USERNAME>
zendesk_password=<ZENDESK_PASSWORD>
rally_username=<RALLY_USERNAME>
rally_password=<RALLY_PASSWORD>

Notes:

If the API complains of password expiry in Zendesk follow this link:

https://company.zendesk.com/access/help

To reset the password. Check access to Zendesk skipping Okta via:

https://company.zendesk.com/access/normal

This password will make the API happy.
");

	exit;
}

sub get_rally_status
{
	my $ticket_id = shift;
	my $stdout;

	printf "\n\e[1;37m** Getting Rally Status for Zendesk Ticket: $ticket_id\e[0m\n\n";

	my $defects = get_rally_defect($ticket_id);

	if (not $defects) {
		printf "Error - No rally defect found for ticket id: $ticket_id\n";
		return;
	}

	$defect_url =~ s/webservice\/v2.0/rally.sp#\/detail/;

	for my $defect ($defects->{'Defect'}) {
		printf("Rally ID:\t%s\n", $defect->{FormattedID}) if defined($defect->{FormattedID});
		printf("Defect Name:\t%s\n", $defect->{_refObjectName}) if defined($defect->{_refObjectName});
		printf("Defect URL:\t%s\n", $defect_url);
        	printf("Defect State:\t%s\n", $defect->{State}) if defined($defect->{State});
        	printf("Schedule State:\t%s\n", $defect->{ScheduleState}) if defined($defect->{ScheduleState});
        	printf("9Box Priority:\t%s\n", $defect->{c_Custom9BoxPriority}) if defined($defect->{c_Custom9BoxPriority});
        	printf("Severity:\t%s\n", $defect->{Severity}) if defined($defect->{Severity});
        	printf("Project:\t%s\n", $defect->{Project}->{_refObjectName}) if defined($defect->{Project}->{_refObjectName});
        	printf("Iteration:\t%s\n", $defect->{Iteration}->{_refObjectName}) if defined($defect->{Iteration}->{_refObjectName});
        	printf("Rally Owner:\t%s\n", $defect->{Owner}->{_refObjectName}) if defined($defect->{Owner}->{_refObjectName});
        	printf("Priority:\t%s\n", $defect->{Priority}) if defined($defect->{Priority});
        	printf("Creation Date:\t%s\n", $defect->{CreationDate}) if defined($defect->{CreationDate});
        	printf("InProgess Date:\t%s\n", $defect->{InProgressDate}) if defined($defect->{InProgressDate});
		printf("9Box ETA Date:\t%s\n", $defect->{c_Custom9BoxETADate}) if defined($defect->{c_Custom9BoxETADate});
        	printf("Last Updated:\t%s\n", $defect->{LastUpdateDate}) if defined($defect->{LastUpdateDate});
	}
}

sub sync_rally_ticket
{
	my $ticket_id = shift;
        my $stdout;

	printf "\n\e[1;37m** Updating Rally Status for Zendesk Ticket: $ticket_id\e[0m\n";

	my $defects = get_rally_defect($ticket_id);

	if (not $defects) {
		printf "Error - No rally defect found for ticket id: $ticket_id\n";
		return;
	}

	my $zd_rally_problem = rally_fields->new();

	$defect_url =~ s/webservice\/v2.0/rally.sp#\/detail/;
	open OUTPUT, '>', \$stdout or die "Can't open OUTPUT: $!";

	for my $defect ($defects->{'Defect'}) {
		printf OUTPUT ("<h1><b>Rally Status</h1></b><hr><pre><code>");
		printf OUTPUT ("Zendesk ID: %s<br>", $defect->{c_ZendeskID}) if defined($defect->{c_ZendeskID});
		printf OUTPUT ("Rally ID: %s<br>", $zd_rally_problem->formatted_id($defect->{FormattedID})) if defined($defect->{FormattedID});
		printf OUTPUT ("Defect Name: %s<br>", $defect->{_refObjectName}) if defined($defect->{_refObjectName});
		printf OUTPUT ("Defect URL: <a href='%s'>%s</a><br>", $defect_url, $defect_url);
		printf OUTPUT ("Defect State: %s<br>", $zd_rally_problem->defstate($defect->{State})) if defined($defect->{State});
		printf OUTPUT ("Schedule State: %s<br>", $zd_rally_problem->schedule_state($defect->{ScheduleState})) if defined($defect->{ScheduleState});
		printf OUTPUT ("9Box Priority: %s<br>", $zd_rally_problem->ninebox($defect->{c_Custom9BoxPriority})) if defined($defect->{c_Custom9BoxPriority});
		printf OUTPUT ("Severity: %s<br>", $defect->{Severity}) if defined($defect->{Severity});
		printf OUTPUT ("Project: %s<br>", $defect->{Project}->{_refObjectName}) if defined($defect->{Project}->{_refObjectName});
		printf OUTPUT ("Iteration: %s<br>", $defect->{Iteration}->{_refObjectName}) if defined($defect->{Iteration}->{_refObjectName});
		printf OUTPUT ("Rally Owner: %s<br>", $defect->{Owner}->{_refObjectName}) if defined($defect->{Owner}->{_refObjectName});
		printf OUTPUT ("Priority: %s<br>", $defect->{Priority}) if defined($defect->{Priority});
		printf OUTPUT ("Creation Date: %s<br>", $defect->{CreationDate}) if defined($defect->{CreationDate});
		printf OUTPUT ("InProgess Date: %s<br>", $defect->{InProgressDate}) if defined($defect->{InProgressDate});
		printf OUTPUT ("9Box ETA Date: %s<br>", $zd_rally_problem->eta($defect->{c_Custom9BoxETADate})) if defined($defect->{c_Custom9BoxETADate});
		printf OUTPUT ("Last Updated: %s<br>", $defect->{LastUpdateDate}) if defined($defect->{LastUpdateDate});
		printf OUTPUT ("</pre></code></html>");
	}

	my %json_data;
	my $json_obj;
	my $content;
	my $etadate = '';

	$etadate = (split(/[T]/,$zd_rally_problem->eta))[0] if defined($zd_rally_problem->eta);

	$json_obj = JSON::XS->new();
	$json_obj->allow_nonref();

	$content = $json_obj->encode($stdout);
	$content =~ s/^"(.*)"$/$1/;

	$json_data{ticket}{comment} = {
		public => "false",
		html_body => $content
	};

	$json_data{ticket}{custom_fields} = [
		{ id => "12345678", value => $zd_rally_problem->formatted_id },
		{ id => "12345678", value => "$defect_url" },
		{ id => "12345678", value => "$zd_rally_problem->schedule_state)" },
		{ id => "12345678", value => "$zd_rally_problem->defstate)" },
		{ id => "12345678", value => "engsup_9box_" . $zd_rally_problem->ninebox },
		{ id => "12345678", value => "$etadate" }
	];

	update_zd_ticket($ticket_id, $json_obj->encode(\%json_data));
}

sub send_eta_response
{
	my $ticket_id = shift;
	my $zd_rally_eta = '';
	my $zd_problem_results = 0;
	my $stdout;

	printf "\n\e[1;37m** Send out Initial ETA Response for Zendesk Ticket: $ticket_id\e[0m\n";

	my $zd_results = get_zd_ticket_id($ticket_id);

	if ($zd_results->{'ticket'}->{'type'} =~ m/^incident$/ and defined($zd_results->{'ticket'}->{'problem_id'})) {
		$zd_problem_results = get_zd_ticket_id($zd_results->{'ticket'}->{'problem_id'});
	}

	if ($zd_results->{'ticket'}->{'type'} =~ m/^problem$/ and $zd_results->{'ticket'}->{'ticket_form_id'} =~ m/^$RAL_FORM$/) {
		$zd_problem_results = $zd_results;
	}

	for my $custom_fields (@{$zd_problem_results->{'ticket'}->{'custom_fields'}}) {
		if ($custom_fields->{'id'} =~ m/^12345678$/) {
			$zd_rally_eta = $custom_fields->{'value'} if $custom_fields->{'value'};
		}
	}

	if (not $zd_rally_eta) {
		printf "Error - No ETA Found.\n";
		return;
	}

	open OUTPUT, '>', \$stdout or die "Can't open OUTPUT: $!";
	printf OUTPUT ("Greetings,<br><br>");
	printf OUTPUT ("Following up on open case #{{ticket.id}} - {{ticket.title}}<br><br>");
	printf OUTPUT ("Development have currently accepted this case as a defect and provided an initial ETA of %s.<br><br>", $zd_rally_eta);
	printf OUTPUT ("Please note this is an initial estimate and this defect could very well be completed sooner than the date provided. ");
	printf OUTPUT ("We will keep you abreast of any further developments as they progress.<br><br>");
	printf OUTPUT ("Thank you for your patience.<br><br>");
	printf OUTPUT ("Kind Regards,");

        my %json_data;
        my $json_obj;
        my $content;

	$json_obj = JSON::XS->new();
	$json_obj->allow_nonref();

	$content = $json_obj->encode($stdout);
	$content =~ s/^"(.*)"$/$1/;

	$json_data{ticket}{comment} = {
		public => "true",
		html_body => $content
	};

	update_zd_ticket($ticket_id, $json_obj->encode(\%json_data));
}

sub send_initial_response
{
	my $ticket_id = shift;
	my $stdout;

	printf "\n\e[1;37m** Send out Initial Response for Zendesk Ticket: $ticket_id\e[0m\n";

	my $zd_results = get_zd_ticket_id($ticket_id);

	open OUTPUT, '>', \$stdout or die "Can't open OUTPUT: $!";
	printf OUTPUT ("Greetings,<br><br>");
	printf OUTPUT ("Following up on open case #{{ticket.id}} - {{ticket.title}}<br><br>");
	printf OUTPUT ("This case has been escalated to the Technical Team for further investigation. ");
	printf OUTPUT ("Should any additional information be required you'll be contacted either by phone or email as soon as an Engineer is available.<br><br>");
	printf OUTPUT ("Thank you for your patience.<br><br>");
	printf OUTPUT ("Kind Regards,");

	my %json_data;
	my $json_obj;
	my $content;

	$json_obj = JSON::XS->new();
	$json_obj->allow_nonref();

	$content = $json_obj->encode($stdout);
	$content =~ s/^"(.*)"$/$1/;

	$json_data{ticket}{comment} = {
		public => "true",
		html_body => $content
	};

	update_zd_ticket($ticket_id, $json_obj->encode(\%json_data));
}

sub send_onit_response
{
	my $ticket_id = shift;
	my $stdout;

	printf "\n\e[1;37m** Send out Working It Response for Zendesk Ticket: $ticket_id\e[0m\n";

	my $zd_results = get_zd_ticket_id($ticket_id);

	open OUTPUT, '>', \$stdout or die "Can't open OUTPUT: $!";
	printf OUTPUT ("Greetings,<br><br>");
	printf OUTPUT ("Following up on open case #{{ticket.id}} - {{ticket.title}}<br><br>");
	printf OUTPUT ("This case is currently being investigated by the Technical Team. ");
	printf OUTPUT ("Should any additional information be required you'll be contacted either by phone or email.<br><br>");
	printf OUTPUT ("Thank you for your patience.<br><br>");
	printf OUTPUT ("Kind Regards,");

	my %json_data;
	my $json_obj;
	my $content;

	$json_obj = JSON::XS->new();
	$json_obj->allow_nonref();

	$content = $json_obj->encode($stdout);
	$content =~ s/^"(.*)"$/$1/;

	$json_data{ticket}{comment} = {
		public => "true",
		html_body => $content
	};

        update_zd_ticket($ticket_id, $json_obj->encode(\%json_data));
}

sub sync_linked_tickets
{
	my $assignee = shift;
	my $zd_results = get_zd_tickets(0, $ZEN_GROUP, "Incident", "Status<Solved", 0, $assignee);
	my $curr_date = localtime->ymd('-');
	my $date_format = '%Y-%m-%d';

	printf "\n\e[1;37m** The following linked incident tickets will be checked for required update..\e[0m\n\n";

	for my $zdr (@{$zd_results}) {
		if ($zdr->{'status'} =~ m/^solved$/ or $zdr->{'status'} =~ m/^closed$/) {
			next;
		}

		if (not defined($zdr->{'problem_id'})) {
			next;
		}

		my $zd_rally_child = rally_fields->new();

		for my $custom_fields (@{$zdr->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->eta($custom_fields->{'value'} //= '');
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->ninebox($custom_fields->{'value'} //= '');
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->schedule_state($custom_fields->{'value'} //= '');
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->defstate($custom_fields->{'value'} //= '');
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->formatted_id($custom_fields->{'value'} //= '');
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_child->defect_url($custom_fields->{'value'} //= '');
			}
		}

		my $zd_rally_problem = rally_fields->new();
		my $zd_problem_id_results = get_zd_ticket_id($zdr->{'problem_id'});

		for my $zdp ($zd_problem_id_results->{'ticket'}) {
			$zd_rally_problem->status($zdp->{'status'});
			for my $custom_fields (@{$zdp->{'custom_fields'}}) {
				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->eta($custom_fields->{'value'} //= '');
				}

				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->ninebox($custom_fields->{'value'} //= '');
				}

				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->schedule_state($custom_fields->{'value'} //= '');
				}

				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->defstate($custom_fields->{'value'} //= '');
				}

				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->formatted_id($custom_fields->{'value'} //= '');
				}

				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_problem->defect_url($custom_fields->{'value'} //= '');
				}
			}
		}

		if (	$zd_rally_child->formatted_id ne $zd_rally_problem->formatted_id or
			$zd_rally_child->defect_url ne $zd_rally_problem->defect_url or
			$zd_rally_child->schedule_state ne $zd_rally_problem->schedule_state or
			$zd_rally_child->defstate ne $zd_rally_problem->defstate or
			$zd_rally_child->eta ne $zd_rally_problem->eta or
			$zd_rally_child->ninebox ne $zd_rally_problem->ninebox) {

			$zd_rally_child->sync_status('Not In Sync');
			$zd_rally_child->sync_action('Updating');

			my %json_data;
			my $json_obj;

			$json_obj = JSON::XS->new();
			$json_obj->allow_nonref();

			$json_data{ticket}{custom_fields} = [
				{ id => "12345678", value => $zd_rally_problem->formatted_id },
				{ id => "12345678", value => $zd_rally_problem->defect_url },
				{ id => "12345678", value => $zd_rally_problem->schedule_state },
				{ id => "12345678", value => $zd_rally_problem->defstate },
				{ id =>	"12345678", value => $zd_rally_problem->eta },
				{ id => "12345678", value => $zd_rally_problem->ninebox }
			];

			update_zd_ticket($zdr->{'id'}, $json_obj->encode(\%json_data));
			next;
		}
		else {
			$zd_rally_child->sync_status('Is In Sync');
			$zd_rally_child->sync_action('OK');
		}

		my $zd_ticket_status = $zdr->{'status'};
		my $days_eta = (Time::Piece->strptime($zd_rally_problem->eta, $date_format) - Time::Piece->strptime($curr_date, $date_format)) / 3600 / 24;
		my %json_data;
		my $json_obj;

		$json_obj = JSON::XS->new();
		$json_obj->allow_nonref();

		if ($zdr->{'status'} !~ m/^solved$/ and $zdr->{'status'} !~ m/^closed$/) {
			if ($zd_rally_child->eta ne "-" and $days_eta >= 0 and $days_eta <= 3 and $zdr->{'status'} =~ m/^hold$/) {
				$zd_ticket_status = "open";
			}
			elsif ($zd_rally_child->eta ne "-" and $days_eta > 3 and $zdr->{'status'} !~ m/^hold$/) {
				$zd_ticket_status = "hold";
			}

			if ($zdr->{'status'} ne $zd_ticket_status) {
				$zd_rally_child->sync_status('Ticket State');
				$zd_rally_child->sync_action('Updating');

				my %json_data;
				my $json_obj;

				$json_obj = JSON::XS->new();
				$json_obj->allow_nonref();

				$json_data{ticket}{status} = $zd_ticket_status;
				update_zd_ticket($zdr->{'id'}, $json_obj->encode(\%json_data));
			}
		}

		printf("%-12s - %-8s - Ticket ID: %8s  (Linked to Problem ID: %8s) Status: %-8s - %-6s, ETA: %-10s, Scheduled State: %s\n",
			$zd_rally_child->sync_status,
			$zd_rally_child->sync_action,
			$zdr->{'id'},
			$zdr->{'problem_id'},
			ucfirst($zd_ticket_status),
			$zd_rally_problem->formatted_id,
			$zd_rally_problem->eta,
			$zd_rally_problem->schedule_state
		);
	}
}

sub get_unassigned_tickets
{
	printf "\n\e[1;37m** Listing Unassigned Cases\e[0m\n\n";

	my $zd_results = get_zd_tickets(0, $ZEN_GROUP, 0, "Status<Solved", 0, "none");
	my $curr_date = localtime->ymd('-');
	my $date_format = '%Y-%m-%d';
	my $datetime_iso_format = '%Y-%m-%dT%H:%M:%SZ';
	my $datetime_format = '%Y-%m-%d %H:%M:%S';
	my $ttot = 0;

	printf("TicketID    ProblemID   Created                Updated                Type        Status      Priority    Days   TTOT  Subject\n");
	printf("--------    ---------   -------                -------                ----        ------      --------    ----   ----  -------\n");

	for my $zdn (@{$zd_results}) {
		my $zd_problem_id = 0;
		my (	$zd_type, 
			$zd_status,
			$zd_priority) = ('-') x 3;
		my $days = 0;
		my $colour = "\e[0m";

		my ($updated_at_date, $updated_at_time) = (split(/[T]/,$zdn->{'updated_at'}))[0,1];

		for my $custom_fields (@{$zdn->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$ttot = $custom_fields->{'value'} / 60 if $custom_fields->{'value'};
			}
		}

		my $zd_bl_s3 = check_bl_s3($zdn->{'tags'});

		if ($ttot < 15 and ($zdn->{'ticket_form_id'} !~ m/^$RAL_FORM$/ or not defined($zdn->{'problem_id'}))) {
			$colour = "\e[1;33m";
		}

		if ($zdn->{'status'} =~ m/^pending$/ and $zd_bl_s3) {
			$colour = "\e[1;36m";
		}
		
		if ($zdn->{'type'} =~ m/^problem$/ and $zdn->{'ticket_form_id'} =~ m/^$RAL_FORM$/) {
			$colour = "\e[1;32m";
		}

		if ($zdn->{'type'} =~ m/^incident$/ and defined($zdn->{'problem_id'})) {
			$colour = "\e[1;32m";
		}

		$days = (Time::Piece->strptime($curr_date, $date_format) - Time::Piece->strptime($updated_at_date, $date_format)) / 3600 / 24;

		if (($zdn->{'status'} =~ m/^open$/ or $zdn->{'status'} =~ m/^new$/)
			and ($zdn->{'priority'} =~ m/^urgent$/ or $zdn->{'priority'} =~ m/^high$/)
			and $days < 3 and not defined($zdn->{'problem_id'})) {
			$colour = "\e[1;37m";
		}

		if (($zdn->{'status'} =~ m/^open$/ or $zdn->{'status'} =~ m/^new$/) and $days > 2 and not defined($zdn->{'problem_id'})) {
			$colour = "\e[1;31m";
		}

		$zd_problem_id = $zdn->{'problem_id'} if defined($zdn->{'problem_id'});
		$zd_type = $zdn->{'type'} if defined($zdn->{'type'});
		$zd_status = $zdn->{'status'} if defined($zdn->{'status'});
		$zd_priority = $zdn->{'priority'} if defined($zdn->{'priority'});

		printf("$colour%-10d  %-10d  %-21s  %-21s  %-10s  %-10s  %-10s  %4d  %4dm  ",
			$zdn->{'id'},
			$zd_problem_id,
			(Time::Piece->strptime($zdn->{'created_at'}, $datetime_iso_format))->strftime($datetime_format),
			(Time::Piece->strptime($zdn->{'updated_at'}, $datetime_iso_format))->strftime($datetime_format),
			ucfirst($zd_type),
			ucfirst($zd_status),
			ucfirst($zd_priority),
			$days,
			$ttot
		);

		if (length($zdn->{'subject'}) >= $CHR_LIMIT) {
			printf("%s..\e[0m\n", substr(ucfirst($zdn->{'subject'}), 0, $CHR_LIMIT));
		}
		else {
			printf("%s\e[0m\n", ucfirst($zdn->{'subject'}));
		}
	}
}

sub get_backlog_tickets
{
	my $assignee = shift;

	printf("\n\e[1;37m** Listing Cases at BackLog Stage 3 for Zendesk User: $assignee\e[0m\n\n");

	my $zd_results = get_zd_tickets($UST_FORM, $ZEN_GROUP, 0, "Status<Solved", 0, $assignee);
	my $curr_date = localtime->ymd('-');
	my $date_format = '%Y-%m-%d';
	my $datetime_iso_format = '%Y-%m-%dT%H:%M:%SZ';
	my $datetime_format = '%Y-%m-%d %H:%M:%S';
	my $ttot = 0;

	printf("TicketID    ProblemID   Created                Updated                Type        Status      Priority    Days   TTOT  Subject\n");
	printf("--------    ---------   -------                -------                ----        ------      --------    ----   ----  -------\n");

	for my $zdb (@{$zd_results}) {
		if ($zdb->{'status'} =~ m/^solved$/ or $zdb->{'status'} =~ m/^closed$/) {
			next;
		}

		my $zd_problem_id = 0;
		my $days = 0;
		my $colour = "\e[0m";
		my ($updated_at_date, $updated_at_time) = (split(/[T]/,$zdb->{'updated_at'}))[0,1];

		for my $custom_fields (@{$zdb->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$ttot = $custom_fields->{'value'} / 60 if $custom_fields->{'value'};
			}
		}

		my $zd_bl_s3 = check_bl_s3($zdb->{'tags'});

		if ($zdb->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and defined($zdb->{'problem_id'})) {
			$colour = "\e[1;32m";
		}

		$days = (Time::Piece->strptime($curr_date, $date_format) - Time::Piece->strptime($updated_at_date, $date_format)) / 3600 / 24;

		if ($zdb->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zdb->{'problem_id'}) and $days >= 7) {
			$colour = "\e[1;31m";
		}

		$zd_problem_id = $zdb->{'problem_id'} if defined($zdb->{'problem_id'});

		if ($zdb->{'status'} =~ m/^pending$/ and $zd_bl_s3) {
			printf("$colour%-10d  %-10d  %-21s  %-21s  %-10s  %-10s  %-10s  %4d  %4dm  ",
				$zdb->{'id'},
				$zd_problem_id,
				(Time::Piece->strptime($zdb->{'created_at'}, $datetime_iso_format))->strftime($datetime_format),
				(Time::Piece->strptime($zdb->{'updated_at'}, $datetime_iso_format))->strftime($datetime_format),
				ucfirst($zdb->{'type'}),
				ucfirst($zdb->{'status'}),
				ucfirst($zdb->{'priority'}),
				$days,
				$ttot
			);

			if (length($zdb->{'subject'}) >= $CHR_LIMIT) {
				printf("%s..\e[0m\n", substr(ucfirst($zdb->{'subject'}), 0, $CHR_LIMIT));
			}
			else {
				printf("%s\e[0m\n", ucfirst($zdb->{'subject'}));
			}
		}
	}
}

sub get_statistics
{
	my $assignee = shift;

	printf("\n\e[1;37m** Listing Ticket Statistics\e[0m (Update: %s)\n", localtime->cdate);

	my (	$open_c, $active_open_c,
		$pending_c, $active_pending_c,
		$new_c, $active_new_c,
		$hold_c, $active_hold_c,
		$unassigned_c, $active_unassigned_c,
		$backlog_c, $active_backlog_c,
		$need_update, $active_need_update,
		$rally_c, $incident_with_rally,
		$rally_new_c, $rally_unassigned_c,
		$rally_backlog_c, $eta_breach,
		$eta_due_7, $eta_due_14,
		$eta_due_21, $eta_none,
		$staff1_ds, $staff2_ds,
		$staff1_ws, $staff2_ws,
		$staff1_ms, $staff2_ms,
		$staff3_ds, $staff4_ds, $staff5_ds, $staff6_ds, $staff7_ds,
		$staff3_ws, $staff4_ws, $staff5_ws, $staff6_ws, $staff7_ws,
		$staff3_ms, $staff4_ms, $staff5_ms, $staff6_ms, $staff7_ms) = (0) x 46;

        my $curr_date = localtime->ymd('-');
        my $date_format = '%Y-%m-%d';
	my $zd_results = get_zd_tickets(0, $ZEN_GROUP, 0, "Status<Solved", 0, (defined($assignee) ? "$assignee" : 0));

	for my $zda (@{$zd_results}) {
		if ($zda->{'status'} =~ m/^solved$/ or $zda->{'status'} =~ m/^closed$/) {
			next;
		}

		if ($zda->{'status'} =~ m/^open$/) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
				$active_open_c++;
			}

			$open_c++;
		}

		if ($zda->{'status'} =~ m/^pending$/) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
				$active_pending_c++;
			}

			$pending_c++;
		}

		if ($zda->{'status'} =~ m/^new$/) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
				$active_new_c++;
			}

			$new_c++;
		}

		if ($zda->{'status'} =~ m/^hold$/) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
				$active_hold_c++;
			}

			$hold_c++;
		}

		my $zd_bl_s3 = check_bl_s3($zda->{'tags'});

		if ($zda->{'status'} =~ m/^pending$/ and $zd_bl_s3) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ or not defined($zda->{'problem_id'})) {
				$active_backlog_c++;
				$active_need_update++;
			}

			if ($zda->{'ticket_form_id'} =~ m/^$RAL_FORM$/) {
				$rally_backlog_c++;
			}

			$backlog_c++;
			$need_update++;
		}

		if (not defined($zda->{'assignee_id'})) {
			if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
				$active_unassigned_c++;
			}
			
			if ($zda->{'ticket_form_id'} =~ m/^$RAL_FORM$/ and $zda->{'type'} =~ m/^problem$/) {
				$rally_unassigned_c++;
			}

			$unassigned_c++;
		}

		if ($zda->{'ticket_form_id'} =~ m/^$RAL_FORM$/ and $zda->{'type'} =~ m/^problem$/) {
			if ($zda->{'status'} =~ m/^new$/) {
				$rally_new_c++;
			}
			else {
				$rally_c++;
			}
		}

		if (defined($zda->{'type'}) and $zda->{'type'} =~ m/^incident$/ and defined($zda->{'problem_id'})) {
			$incident_with_rally++;
		}

		if ($zda->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and not defined($zda->{'problem_id'})) {
			my ($updated_at_date, $updated_at_time) = (split(/[T]/,$zda->{'updated_at'}))[0,1];
			my $days = (Time::Piece->strptime($curr_date, $date_format) - Time::Piece->strptime($updated_at_date, $date_format)) / 3600 / 24;
			if (($zda->{'status'} =~ m/^open$/ or $zda->{'status'} =~ m/^new$/ or $zda->{'status'} =~ m/^pending$/) and $days > 3 and not $zd_bl_s3) {
				$active_need_update++;
				$need_update++;
			}
		}

		if ($zda->{'ticket_form_id'} =~ m/^$RAL_FORM$/ and $zda->{'type'} =~ m/^problem$/) {
			my $zd_rally_eta = "-";
			for my $custom_fields (@{$zda->{'custom_fields'}}) {
				if ($custom_fields->{'id'} =~ m/^12345678$/) {
					$zd_rally_eta = $custom_fields->{'value'} if $custom_fields->{'value'};
				}
			}

			if ($zd_rally_eta ne "-") {
                        	my $days_eta = (Time::Piece->strptime($zd_rally_eta, $date_format) - Time::Piece->strptime($curr_date, $date_format)) / 3600 / 24;

                        	if ($days_eta >= 0 and $days_eta <= 7) {
                        	        $eta_due_7++;
                        	}

				if ($days_eta > 7 and $days_eta <= 14) {
					$eta_due_14++;
				}

				if ($days_eta > 14 and $days_eta <= 21) {
					$eta_due_21++;
				}

                        	if ($days_eta < 0) {
                        	        $eta_breach++;
					$rally_backlog_c++;
					$need_update++;
				}
			}
			else {
				$eta_none++;
				$need_update++;
			}
		}
	}

	my $zd_daily_solved_results = get_zd_tickets(0, $ZEN_GROUP, 0, "", "Solved>=1day", 0);

	for my $zdd (@{$zd_daily_solved_results}) {
		$staff1_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff2_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff3_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff4_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff5_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff6_ds++ if ($zdd->{'assignee_id'} eq 123456789);
		$staff7_ds++ if ($zdd->{'assignee_id'} eq 123456789);
	}

	my $zd_weekly_solved_results = get_zd_tickets(0, $ZEN_GROUP, 0, "", "Solved>=1week", 0);

	for my $zdw (@{$zd_weekly_solved_results}) {
		$staff1_ws++ if ($zdw->{'assignee_id'} eq 123456789);
		$staff2_ws++ if ($zdw->{'assignee_id'} eq 123456789);
		$staff3_ws++ if	($zdw->{'assignee_id'} eq 123456789);
		$staff4_ws++ if ($zdw->{'assignee_id'} eq 123456789);
		$staff5_ws++ if ($zdw->{'assignee_id'} eq 123456789);
		$staff6_ws++ if ($zdw->{'assignee_id'} eq 123456789);
		$staff7_ws++ if ($zdw->{'assignee_id'} eq 123456789);
	}

	my $period_month_start = sprintf '%04d-%02d-%02d', localtime->year, localtime->mon, 1;
	my $period_month_last_day = Time::Piece->strptime($period_month_start, '%Y-%m-%d')->month_last_day;
	my $period_month_end = sprintf '%04d-%02d-%02d', localtime->year, localtime->mon, $period_month_last_day;

	my $zd_monthly_solved_results = get_zd_tickets(0, $ZEN_GROUP, 0, "", "Solved>=$period_month_start Solved<=$period_month_end", 0);

	for my $zdm (@{$zd_monthly_solved_results}) {
		$staff1_ms++ if ($zdm->{'assignee_id'} eq 123456789);
		$staff2_ms++ if ($zdm->{'assignee_id'} eq 123456789);
		$staff3_ms++ if	($zdm->{'assignee_id'} eq 123456789);
		$staff4_ms++ if ($zdm->{'assignee_id'} eq 123456789);
		$staff5_ms++ if ($zdm->{'assignee_id'} eq 123456789);
		$staff6_ms++ if ($zdm->{'assignee_id'} eq 123456789);
		$staff7_ms++ if ($zdm->{'assignee_id'} eq 123456789);
	}

	printf("
All Tickets                 Active Tickets             Rally Tickets              Rally ETA                     Solved            D    W    M
-----------------           -----------------          -----------------          ---------------------         -------------------------------
Open        : %-6d        Open        : %-6d       Problem     : %-6d       \e[1;37mETA Unassigned\e[0m  : \e[1;31m%-6d\e[0m      Staff 1    %-2d   %-2d   %-2d
Pending     : %-6d        Pending     : %-6d       Linked      : %-6d       \e[1;37mETA Breach\e[0m      : \e[1;31m%-6d\e[0m      Staff 2    %-2d   %-2d   %-2d
New         : %-6d        New         : %-6d       New         : %-6d       ETA Due 7 Days  : \e[1;33m%-6d\e[0m      Staff 3     %-2d   %-2d   %-2d
Unassigned  : %-6d        Unassigned  : %-6d       Unassigned  : %-6d       ETA Due 14 Days : %-6d      Staff 4         %-2d   %-2d   %-2d
\e[1;37mBacklog\e[0m     : \e[1;36m%-6d\e[0m        \e[1;37mBacklog\e[0m     : \e[1;36m%-6d\e[0m       \e[1;37mBacklog\e[0m     : \e[1;31m%-6d\e[0m       ETA Due 21 Days : %-6d      Staff 5     %-2d   %-2d   %-2d
\e[1;37mNeed Update\e[0m : \e[1;31m%-6d\e[0m        \e[1;37mNeed Update\e[0m : \e[1;31m%-6d\e[0m       \e[1;37mNeed Update\e[0m : \e[1;31m%-6d\e[0m                                     Staff 6    %-2d   %-2d   %-2d
-----------------           -----------------          -----------------                                        Staff 7     %-2d   %-2d   %-2d
Total       : \e[1;37m%-6d\e[0m        Total       : \e[1;37m%-6d\e[0m       Total       : \e[1;37m%-6d\e[0m                                     -------------------------------
                                                                                                                Total             \e[1;37m%-3d  %-3d  %-3d\e[0m
",
		$open_c, $active_open_c, $rally_c, $eta_none, $staff1_ds, $staff1_ws, $staff1_ms,
		$pending_c, $active_pending_c, $incident_with_rally, $eta_breach, $staff2_ds, $staff2_ws, $staff2_ms,
		$new_c, $active_new_c, $rally_new_c, $eta_due_7, $staff3_ds, $staff3_ws, $staff3_ms,
		$unassigned_c, $active_unassigned_c, $rally_unassigned_c, $eta_due_14, $staff4_ds, $staff4_ws, $staff4_ms,
		($backlog_c + $rally_backlog_c), $active_backlog_c, $rally_backlog_c, $eta_due_21, $staff5_ds, $staff5_ws, $staff5_ms,
		$need_update, $active_need_update, ($eta_none + $eta_breach), $staff6_ds, $staff6_ws, $staff6_ms, $staff7_ds, $staff7_ws, $staff7_ms,
		($new_c + $open_c + $pending_c + $hold_c), ($active_new_c + $active_open_c + $active_pending_c + $active_hold_c), ($rally_c + $rally_new_c + $incident_with_rally),
		($staff1_ds + $staff2_ds + $staff3_ds + $staff4_ds + $staff5_ds + $staff6_ds + $staff7_ds),
		($staff1_ws + $staff2_ws + $staff3_ws + $staff4_ws + $staff5_ws + $staff6_ws + $staff7_ws),
		($staff1_ms + $staff2_ms + $staff3_ms + $staff4_ms + $staff5_ms + $staff6_ms + $staff7_ms)
	);	
}

sub get_active_tickets
{
	my $assignee = shift;

	printf "\n\e[1;37m** Listing Active Cases for Zendesk User: $assignee\e[0m\n\n";

	my $zd_results = get_zd_tickets($UST_FORM, $ZEN_GROUP, 0, "Status<Solved", 0, $assignee);
	my $curr_date = localtime->ymd('-');
	my $date_format = '%Y-%m-%d';
	my $datetime_iso_format = '%Y-%m-%dT%H:%M:%SZ';
	my $datetime_format = '%Y-%m-%d %H:%M:%S';
	my $ttot = 0;

	printf("TicketID    ProblemID   Created                Updated                Type        Status      Priority    Days   TTOT  Subject\n");
	printf("--------    ---------   -------                -------                ----        ------      --------    ----   ----  -------\n");

	for my $zda (@{$zd_results}) {
		if ($zda->{'status'} =~ m/^closed$/ or $zda->{'status'} =~ m/^solved$/) {
			next;
		}

		my $zd_problem_id = 0;
		my (	$zd_type,
			$zd_status,
			$zd_priority) = ('-') x 3;
                my $days = 0;
		my $colour = "\e[0m";
		my ($updated_at_date, $updated_at_time) = (split(/[T]/,$zda->{'updated_at'}))[0,1];

		for my $custom_fields (@{$zda->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$ttot = $custom_fields->{'value'} / 60 if $custom_fields->{'value'};
			}
 		}

		my $zd_bl_s3 = check_bl_s3($zda->{'tags'});

		$days = (Time::Piece->strptime($curr_date, $date_format) - Time::Piece->strptime($updated_at_date, $date_format)) / 3600 / 24;

		if ($zda->{'status'} =~ m/^open$/ and $days > 3 and not defined($zda->{'problem_id'})) {
			$colour = "\e[1;31m";
		}

		if ($zda->{'status'} =~ m/^pending$/ and $zd_bl_s3) {
			$colour = "\e[1;36m";
		}

		if (defined($zda->{'type'}) and $zda->{'type'} =~ m/^incident$/ and defined($zda->{'problem_id'}) and not $zd_bl_s3) {
			$colour = "\e[1;32m";
		}

		$zd_problem_id = $zda->{'problem_id'} if defined($zda->{'problem_id'});
		$zd_type = $zda->{'type'} if defined($zda->{'type'});
		$zd_status = $zda->{'status'} if defined($zda->{'status'});
		$zd_priority = $zda->{'priority'} if defined($zda->{'priority'});

		printf("$colour%-10d  %-10d  %-21s  %-21s  %-10s  %-10s  %-10s  %4d  %4dm  ",
			$zda->{'id'},
			$zd_problem_id,
                	(Time::Piece->strptime($zda->{'created_at'}, $datetime_iso_format))->strftime($datetime_format),
                	(Time::Piece->strptime($zda->{'updated_at'}, $datetime_iso_format))->strftime($datetime_format),
			ucfirst($zd_type),
			ucfirst($zd_status),
			ucfirst($zd_priority),
			$days,
			$ttot
		);

		if (length($zda->{'subject'}) >= $CHR_LIMIT) {
			printf("%s..\e[0m\n", substr(ucfirst($zda->{'subject'}), 0, $CHR_LIMIT));
		}
		else {
			printf("%s\e[0m\n", ucfirst($zda->{'subject'}));
		}
	}
}

sub get_linked_tickets
{
        my $ticket_id = shift;

        printf "\n\e[1;37m** Listing all incident tickets for problem ticket id: $ticket_id\e[0m\n\n";

        my $zd_results = get_linked_incidents($ticket_id);
        my $curr_date = localtime->ymd('-');
        my $date_format = '%Y-%m-%d';
        my $datetime_iso_format = '%Y-%m-%dT%H:%M:%SZ';
        my $datetime_format = '%Y-%m-%d %H:%M:%S';
        my $ttot = 0;

        printf("TicketID    ProblemID   Created                Updated                Type        Status      Priority    Days   TTOT  Subject\n");
        printf("--------    ---------   -------                -------                ----        ------      --------    ----   ----  -------\n");

	for my $zdl (@{$zd_results->{'tickets'}}) {
		my $zd_problem_id = 0;
		my $days = 0;
 		my $colour = "\e[0m";
 		my ($updated_at_date, $updated_at_time) = (split(/[T]/,$zdl->{'updated_at'}))[0,1];

		for my $custom_fields (@{$zdl->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$ttot = $custom_fields->{'value'} / 60 if $custom_fields->{'value'};
			}
 		}

		$days = (Time::Piece->strptime($curr_date, $date_format) - Time::Piece->strptime($updated_at_date, $date_format)) / 3600 / 24;

		if ($zdl->{'group_id'} !~ m/^$ZEN_GROUP$/ or ($zdl->{'ticket_form_id'} !~ m/^$RAL_FORM$/ and defined($zdl->{'problem_id'}))) {
			$colour = "\e[1;32m";
		}

		$zd_problem_id = $zdl->{'problem_id'} if defined($zdl->{'problem_id'});
		printf("$colour%-10d  %-10d  %-21s  %-21s  %-10s  %-10s  %-10s  %4d  %4dm  ",
			$zdl->{'id'},
			$zd_problem_id,
			(Time::Piece->strptime($zdl->{'created_at'}, $datetime_iso_format))->strftime($datetime_format),
			(Time::Piece->strptime($zdl->{'updated_at'}, $datetime_iso_format))->strftime($datetime_format),
			ucfirst($zdl->{'type'}),
			ucfirst($zdl->{'status'}),
			ucfirst($zdl->{'priority'}),
			$days,
			$ttot
		);

		if (length($zdl->{'subject'}) >= $CHR_LIMIT) {
			printf("%s..\e[0m\n", substr(ucfirst($zdl->{'subject'}), 0, $CHR_LIMIT));
		}
		else {
			printf("%s\e[0m\n", ucfirst($zdl->{'subject'}));
		}
	}
}

sub get_ticket_info
{
	my $ticket_id = shift;

	printf "\n\e[1;37m** Review ticket information for ticket id: $ticket_id\e[0m\n\n";

	my $zdt = get_zd_ticket_id($ticket_id);

	printf("Ticket ID:\t%s\n", $zdt->{ticket}{id}) if defined($zdt->{ticket}{id});
	printf("Ticket URL:\thttps://company.zendesk.com/agent/tickets/%s\n", $zdt->{ticket}{id}) if defined($zdt->{ticket}{id});
	printf("Priority:\t%s\n", ucfirst($zdt->{ticket}{priority})) if defined($zdt->{ticket}{priority});
	printf("Status:  \t%s\n", ucfirst($zdt->{ticket}{status})) if defined($zdt->{ticket}{status});
	printf("Created:\t%s\n", ucfirst($zdt->{ticket}{created_at})) if defined($zdt->{ticket}{created_at});
	printf("Updated:\t%s\n", $zdt->{ticket}{updated_at}) if defined($zdt->{ticket}{updated_at});
	printf("Subject:\t%s\n\n", $zdt->{ticket}{subject}) if defined($zdt->{ticket}{subject});
	printf("Description:\n\n");
	printf("%-100s\n", $zdt->{ticket}{description});
}

sub get_rally_tickets
{
	my $assignee = shift;

	printf "\n\e[1;37m** Listing Rally Cases for Zendesk User: $assignee\e[0m\n\n";

	my $zd_results = get_zd_tickets($RAL_FORM, $ZEN_GROUP, 0, "Status<Solved", 0, $assignee);
	my $curr_date = localtime->ymd('-');
	my $date_format = '%Y-%m-%d';
	my $datetime_iso_format = '%Y-%m-%dT%H:%M:%SZ';
	my $datetime_format = '%Y-%m-%d';
	my $ttot = 0;

	printf("TicketID    ProblemID   Created       Updated       Type        Priority    Days   TTOT  ETA         Defect State   Schedule State   Subject\n");
	printf("--------    ---------   -------       -------       ----        --------    ----   ----  ---         ------------   --------------   -------\n");

	for my $zdr (@{$zd_results}) {
		if ($zdr->{'status'} =~ m/^solved$/ and $zdr->{'status'} =~ m/^closed$/) {
			next;
		}

		my $zd_problem_id = 0;
		my $zd_rally_eta = "-";
		my $zd_defstate = "";
		my $zd_schedule_state = "";

		$zd_problem_id = $zdr->{'problem_id'} if $zdr->{'problem_id'};

		for my $custom_fields (@{$zdr->{'custom_fields'}}) {
			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_rally_eta = $custom_fields->{'value'} if $custom_fields->{'value'};
			}

        	        if ($custom_fields->{'id'} =~ m/^12345678$/) {
                	        $zd_schedule_state = $custom_fields->{'value'} if $custom_fields->{'value'};
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$zd_defstate = $custom_fields->{'value'} if $custom_fields->{'value'};
			}

			if ($custom_fields->{'id'} =~ m/^12345678$/) {
				$ttot = $custom_fields->{'value'} / 60 if $custom_fields->{'value'};
			}
		}

		my $zd_bl_s3 = check_bl_s3($zdr->{'tags'});
		my $days_eta = 0;
		my $colour = "\e[0m";

		if ($zd_rally_eta ne "-") {
			$days_eta = (Time::Piece->strptime($zd_rally_eta, $date_format) - Time::Piece->strptime($curr_date, $date_format)) / 3600 / 24;
			if ($days_eta >= 0 and $days_eta <= 7 and lc($zd_schedule_state) ne "released") {
				$colour = "\e[1;33m";
			}

			if ($days_eta < 0) {
				$colour = "\e[1;31m";
			}

			if ($days_eta >= 0 and lc($zd_defstate) eq "closed") {
				$colour = "\e[1;32m";
			}

			if ($days_eta >= 0 and lc($zd_schedule_state) eq "released") {
				$colour = "\e[1;32m";
			}
		}
		else {
			$colour = "\e[1;31m";
		}

		if ($zdr->{'status'} =~ m/^pending$/ and $zd_bl_s3) {
			$colour = "\e[1;36m";
		}

		printf("$colour%-10d  %-10d  %-12s  %-12s  %-10s  %-10s  %4d  %4dm  %-10s  %-13s  %-15s  ",
			$zdr->{'id'},
			$zd_problem_id,
			(Time::Piece->strptime($zdr->{'created_at'}, $datetime_iso_format))->strftime($datetime_format),
			(Time::Piece->strptime($zdr->{'updated_at'}, $datetime_iso_format))->strftime($datetime_format),
			ucfirst($zdr->{'type'}),
			ucfirst($zdr->{'priority'}),
			$days_eta,
			$ttot,
			$zd_rally_eta,
			ucfirst($zd_defstate),
			ucfirst($zd_schedule_state)
		);

		if (length($zdr->{'subject'}) >= $CHR_LIMIT) {
			printf("%s..\e[0m\n", substr(ucfirst($zdr->{'subject'}), 0, $CHR_LIMIT));
		}
		else {
			printf("%s\e[0m\n", ucfirst($zdr->{'subject'}));
		}
	}
}

sub get_rally_defect
{
	my $ticket_id = shift;

	my $ua = LWP::UserAgent->new(
			ssl_opts => { verify_hostname => 0 },
			show_progress => 0);

	# Generic Rally read-only API Key.

	my $res = $ua->get(
		"$RAL_URL/defect?query=\(c_ZendeskID%20=%20$ticket_id\)",
		"zsessionid" => "$RAL_KEY",
		"Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	my $json = decode_json($res->decoded_content());

	for my $queryresult ($json->{'QueryResult'}) {
		for my $results (@{$queryresult->{'Results'}}) {
			$defect_url = $results->{'_ref'};
		}
	}

	if (not defined($defect_url)) {
		return 0;
	}

	$ua = LWP::UserAgent->new(
			ssl_opts =>{ verify_hostname => 0 },
			show_progress => 0);

	$res = $ua->get(
		$defect_url,
		"zsessionid" => "$RAL_KEY",
                "Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	$json = decode_json($res->decoded_content());

	return $json;
}

sub update_zd_ticket
{
	my $ticket_id = shift;
	my $json = shift;

	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
	my $url = "$ZEN_URL/tickets/$ticket_id.json";
	my $req = HTTP::Request->new(PUT => $url);

	$req->header("Authorization" => "Basic $ZEN_API_AUTH");
	$req->header("Cache-Control" => "no-cache");
	$req->header("Content-Type" => "application/json");
 	$req->content($json);

	my $res = $ua->request($req);

	unless ($res->is_success) {
		warn ("Error Updating Ticket: " . $ticket_id . " - API returned: " . $res->content() . "\n");
	}
}

sub get_zd_tickets
{
	my $ticket_form_id = shift;
	my $ticket_group = shift;
	my $ticket_type = shift;
	my $ticket_status = shift;
	my $ticket_solved = shift;
	my $assignee = shift;

	my $ticket_form_id_s = ($ticket_form_id ne 0) ? "ticket_form_id:$ticket_form_id" : "";
	my $ticket_group_s = ($ticket_group ne 0) ? "group_id:$ticket_group" : "";
	my $ticket_type_s = ($ticket_type ne 0) ? "ticket_type:$ticket_type" : "";
	my $ticket_status_s = ($ticket_status ne 0) ? "$ticket_status" : "Status<Solved";
	my $ticket_solved_s = ($ticket_solved ne 0) ? "$ticket_solved" : "";
	my $assignee_s;

	if ($assignee !~ m/^none$/ and $assignee ne 0) {
		$assignee_s = "assignee:$assignee";
	}
	else {
		$assignee_s = "assignee:none";
	}

	if ($assignee eq 0) {
		$assignee_s = "";
	}

	my @results;
	my $url = "$ZEN_URL/search.json?query=$ticket_group_s+$ticket_form_id_s+$assignee_s+$ticket_type_s+$ticket_status_s+$ticket_solved_s+type:ticket+order_by:ticket_type+sort:desc";
	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });

	while ($url) {
		my $res = $ua->get(
			$url,
			"Authorization" => "Basic $ZEN_API_AUTH",
			"Cache-Control" => "no-cache"
		);

		unless ($res->is_success) {
			die ("Error - API returned: " . $res->content() . "\n");
		}

		my $json = decode_json($res->content);
		push @results, @{$json->{'results'}};

		if (defined $json->{'next_page'}) {
			$url = $json->{'next_page'};
		}
		else {
			$url = "";
		}
	}

	return \@results;
}

sub get_zd_ticket_id
{
	my $ticket_id = shift;
	my $json;

	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
	my $res = $ua->get(
		"$ZEN_URL/tickets/$ticket_id.json",
		"Authorization" => "Basic $ZEN_API_AUTH",
		"Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	$json = decode_json($res->decoded_content());

	return $json;
}

sub get_linked_incidents
{
	my $ticket_id = shift;
	my $json;

	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
	my $res = $ua->get(
		"$ZEN_URL/tickets/$ticket_id/incidents.json",
		"Authorization" => "Basic $ZEN_API_AUTH",
		"Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	$json = decode_json($res->decoded_content());

	return $json;
}

sub get_ticket_metrics
{
	my $ticket_id = shift;
	my $json;

	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
	my $res = $ua->get(
		"$ZEN_URL/tickets/$ticket_id/metrics.json",
		"Authorization" => "Basic $ZEN_API_AUTH",
		"Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	$json = decode_json($res->decoded_content());

	return $json;
}

sub get_view
{
	my $view_id = shift;
	my $json;

	my $ua = LWP::UserAgent->new(ssl_opts =>{ verify_hostname => 0 });
	my $res = $ua->get(
		"$ZEN_URL/views/$view_id/execute.json",
		"Authorization" => "Basic $ZEN_API_AUTH",
		"Cache-Control" => "no-cache"
	);

	unless ($res->is_success) {
		die ("Error - API returned: " . $res->content() . "\n");
	}

	$json = decode_json($res->decoded_content());

	return $json;
}

sub check_bl_s3
{
	my $results = shift;

	for my $tags (@{$results}) {
		if (not $tags =~ m/^bl_s4$/ or not $tags =~ m/^bl_s_resolve$/) {
			if ($tags =~ m/^bl_s3$/) {
				return 1;
			}
		}
		else {
			next;
		}
	}

	return 0;
}

sub config_parse
{
 	my $config = shift;
	my $up_username = shift;
	my $pp_password = shift;

	my ($username, $password) = ('') x 2;

	open my $config_h, '<', $config
		or die "Error - Failed to open '$config': $!\n";

	while (<$config_h>) {
		chomp;
		next if /^\s*$|^\s*#/;

		if (/^$up_username=/) {
			$username = (split/=/, $_, 2)[1];
		}

		if (/^$pp_password=/) {
 			$password = (split/=/, $_, 2)[1];
		}
	}

	close $config_h
		or die "Error - Failed to close '$config': $!\n";

	die "Error - Failed to find username\n" if ! $username;
	die "Error - Failed to find password\n" if ! $password;

	chomp(my $creds = encode_base64("$username:$password"));

	return $creds;
}

sub get_month
{
	my ($month, $year) = (localtime->mon, localtime->year);
	my $period_start = sprintf '%04d-%02d-%02d', $year, $month, 1;
	my $period_end = do {
		my $tp = Time::Piece->strptime($period_start, '%Y-%m-%d');
		sprintf '%04d-%02d-%02d', $year, $month, $tp->month_last_day;
	};
}
