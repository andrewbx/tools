#!/usr/bin/env perl
#--------------------------------------------------------------------------
# Program     : athena.pl
# Version     : v1.0-STABLE-2019-03-19
# Description : Retrieve Athena DB Content - Requires AWS Access Key
# Syntax      : athena.pl <--db/--query/-d/-q>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

use strict;
use warnings;
use experimental 'signatures';
use Data::GUID 'guid_string';
use Getopt::Long qw/:config no_ignore_case/;
use Text::ASCIITable;
use Net::Amazon::S3;
use Paws;
use Text::CSV;

binmode( STDOUT, ":encoding(UTF-8)" );

our $version    = "v1.0-STABLE";
our $release    = "Athena $version";
our $s3bucket   = "s3://aws-athena-query-results-cli-tool/$ENV{USER}/";
our $def_db     = "db-east";
our $def_region = "us-east-1";

@ARGV or help();

{
    my ( %args, %opts );

    GetOptions(
        'd|db=s'     => \$opts{database},
        'r|region=s' => \$opts{region},
        'o|output=s' => \$opts{output},
        'f|format'   => \$opts{format},
        'v|verbose'  => \$opts{verbose},
        'q|query=s'  => \$args{query},
        'help'       => \$args{help},
        'version'    => \$args{version}
    ) or help();

    if ( $args{help} ) {
        exit help();
    }

    if ( $args{version} ) {
        exit print("$release\n");
    }

    if ( $args{query} ) {
        if ( !$opts{database} ) { $opts{database} = $def_db; }
        if ( !$opts{region} )   { $opts{region}   = $def_region; }

        # Process Athena Query using Paws service.

        my $athena = Paws->service( 'Athena', region => $opts{region} );
        my $query  = $athena->StartQueryExecution(
            QueryString           => $args{query},
            ResultConfiguration   => { OutputLocation => $s3bucket, },
            QueryExecutionContext => { Database       => $opts{database}, },
            ClientRequestToken    => guid_string(),
        );

        my $status;
        do {
            $status = $athena->GetQueryExecution(
                QueryExecutionId => $query->QueryExecutionId, );
            sleep 1;
        } until is_complete($status);

        my $s     = $status->QueryExecution->Status;
        my $start = DateTime->from_epoch( epoch => $s->SubmissionDateTime );
        my $end   = DateTime->from_epoch( epoch => $s->CompletionDateTime );
        my $state = $s->State;

        print(
"\nAthena Query Status: $state, Start Time: $start, End Time: $end\n"
        ) if ( $opts{verbose} );

        # Create and Download the CSV from S3.

        print("Amazon S3 Bucket: $s3bucket\n") if ( $opts{verbose} );

        my $aws = Paws::Credential::ProviderChain->new->selected_provider;
        my $s3  = Net::Amazon::S3->new(
            aws_access_key_id     => $aws->access_key,
            aws_secret_access_key => $aws->secret_key,
        );

        my ( $bucket_name, $key, $file ) = parse_s3_url(
            $status->QueryExecution->ResultConfiguration->OutputLocation );
        my $bucket = $s3->bucket($bucket_name);
        my $local  = './' . $file;

        print("Download CSV File to Local: $local\n") if ( $opts{verbose} );
        $bucket->get_key_filename( $key, 'GET', $local );

        print("Delete $s3bucket$file\n") if ( $opts{verbose} );
        $bucket->delete_key($key);

        print("Delete $s3bucket$file.metadata\n\n") if ( $opts{verbose} );
        $bucket->delete_key( $key . ".metadata" );

        # Process the CSV for output methods.

        open( my $fh, '<', $file ) or die "Could not open '$file' $!\n";
        my $csv = Text::CSV->new(
            {
                binary    => 1,
                auto_diag => 1,
            }
        );

        # Standard tabbed output or table.

        if ( !defined( $opts{output} ) or $opts{output} =~ m/table/i ) {
            if ( !defined( $opts{format} ) ) {
                $csv->header($fh);
                while ( my $row = $csv->getline($fh) ) {
                    local $" = "\t";
                    print "@$row\n";
                }
            }
            else {
                my $table = Text::ASCIITable->new(
                    { alignHeadRow => 'left', reportErrors => 0 } );
                $table->setCols(
                    [
                        map { defined $_ ? $_ : "undef" }
                          @{ $csv->getline($fh) }
                    ]
                );
                while ( my $row = $csv->getline($fh) ) {
                    $table->addRow($row);
                }
                print $table->draw();
            }
        }

        # Close and delete the local file.

        close $fh;
        unlink $file;
    }
}

sub is_complete ($s) {
    $s->QueryExecution->Status->State =~ m/^(?:succeeded|failed|cancelled)$/i;
}

sub parse_s3_url ($url) {
    $url =~ s/^s3:\/\///;
    my ( $bucket, $key ) = split qr(/), $url, 2;
    my ($file) = ( $key =~ m(.*?/?([^/]+)$) );
    return ( $bucket, $key, $file );
}

sub help {
    $0 =~ s{.*/}{};
    printf( "
\033[1m$release\033[0m - Retrieve Athena DB Information.

\033[1mUsage:\033[0m
  $0	-q|--query <sql query>	SQL Query

\033[1mOptions:\033[0m
  -d|db		<db-west|db-east>	Choose Database (Default=db-east)
  -r|region	<region>		Choose region (Default=us-east-1)
  -o|output	<table>			Output format for DB Query. (Default=table)
  -f|format				Output in a formatted table if table specified above.
  --help				Print this help information.
  --verbose				Print more output.
  --version				Print version.

" );

    exit;
}
