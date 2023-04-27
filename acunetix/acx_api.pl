#!/usr/bin/perl
#--------------------------------------------------------------------------
# Program     : acx_api.pl
# Version     : v0.6.1-STABLE-2018-06-01
# Description : Retrieve Acunetix v11 API information.
# Syntax      : acx_api.pl <option>
# Author      : Andrew (andrew@devnull.uk)
#--------------------------------------------------------------------------

use strict;
use warnings;

use JSON qw(encode_json decode_json);
use LWP::UserAgent;
use Getopt::Long qw/:config no_ignore_case/;

binmode( STDOUT, ":encoding(UTF-8)" );

our $VERSION = "v0.6.1-STABLE";
our $RELEASE = "Acunetix v11 API $VERSION";
our $CONFIG  = "$ENV{'HOME'}/.acx_api";
our $PORT    = 1111;

if ( not -f $CONFIG ) {
    warn "\nError - Configuration file not found.\n";
    help_config();
}

@ARGV or help();

{
    my ( %args, %opts );
    my $dc;

    GetOptions(
        'i|ip=s'  => \$opts{host},
        'api=s'   => \$args{api},
        'help'    => \$args{help},
        'version' => \$args{version}
    ) or help();

    if ( $args{help} ) {
        exit help();
    }

    if ( $args{version} ) {
        exit print("$RELEASE\n");
    }

    if ( !$opts{host} ) {
        print "Error - Acunetix Scanner IP required.\n";
        exit help();
    }

    if ( !$args{api} ) {
        print "Error - API query expected.\n";
        exit help();
    }

    my $acx_endpoint = "https://" . $opts{host} . ":$PORT/api/v1";
    my $x_auth_token = get_x_auth_token( $CONFIG, $acx_endpoint );

    if ( $args{api} ) {
        my $json = JSON->new;
        print $json->pretty->encode(
            get_api_query( $CONFIG, $x_auth_token, $acx_endpoint, $args{api} )
        );
    }
}

sub help {
    $0 =~ s{.*/}{};
    printf( "
\033[1m$RELEASE\033[0m - Retrieve Acunetix v11 API information.

\033[1mUsage:\033[0m
  $0	-i|--ip	<host>  --api	<api query>

\033[1mOptions:\033[0m
  -i|--ip 	<Acunetix IP>		Acuentix Scanner IP.
  --help				Print this help information.
  --version				Print version.
" );

    exit;
}

sub help_config {
    printf(
        "\nThe tool makes API calls using the credentials in $CONFIG.

File Format:

acx_username=<ACX_USERNAME>
acx_password=<ACX_PASSWORD>
"
    );

    exit;
}

sub get_api_query {
    my $config       = shift;
    my $x_auth_token = shift;
    my $ip           = shift;
    my $argv         = shift;
    my $json;

    my $ua = LWP::UserAgent->new(
        ssl_opts      => { verify_hostname => 0, SSL_verify_mode => 0x00 },
        show_progress => 1
    );

    my $res = $ua->get(
        "$ip/$argv",
        "X-Auth" => "$x_auth_token",
        "Cookie" => "ui_session=$x_auth_token"
    );

    unless ( $res->is_success ) {
        die("Error - API returned NULL\n");
    }

    $json = decode_json( $res->decoded_content() );
    return $json;
}

sub config_parse {
    my $config      = shift;
    my $up_username = shift;
    my $pp_password = shift;

    my ( $username, $password ) = ('') x 2;

    open my $config_h, '<', $config
      or die "Error - Failed to open '$config': $!\n";

    while (<$config_h>) {
        chomp;
        next if /^\s*$|^\s*#/;

        if (/^$up_username=/) {
            $username = ( split /=/, $_ )[1];
        }

        if (/^$pp_password=/) {
            $password = ( split /=/, $_ )[1];
        }
    }

    close $config_h
      or die "Error - Failed to close '$config': $!\n";

    die "Error - Failed to find username\n" if !$username;
    die "Error - Failed to find password\n" if !$password;

    return $username, $password;
}

sub get_x_auth_token {
    my $config = shift;
    my $ip     = shift;
    my @creds  = config_parse( $config, "acx_username", "acx_password", 0 );

    my $req_token = HTTP::Request->new;
    $req_token->method('POST');
    $req_token->content_type("application/json");
    $req_token->uri("$ip/me/login");

    my $auth_payload =
        '{"email":"'
      . $creds[0]
      . '","password":"'
      . $creds[1]
      . '","remember_me":false}';

    $req_token->content($auth_payload);

    my $ua = LWP::UserAgent->new(
        ssl_opts      => { verify_hostname => 0, SSL_verify_mode => 0x00 },
        show_progress => 0
    );

    my $res = $ua->request($req_token);

    die "Error - ${$res->decoded_content}\n"
      if $res->is_error;

    return $res->header('x-auth');
}
