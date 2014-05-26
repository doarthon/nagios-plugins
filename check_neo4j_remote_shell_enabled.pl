#!/usr/bin/perl -T
# nagios: -epn
#
#  Author: Hari Sekhon
#  Date: 2014-05-26 19:34:51 +0100 (Mon, 26 May 2014)
#
#  http://github.com/harisekhon
#
#  License: see accompanying LICENSE file
#

$DESCRIPTION = "Nagios Plugin to check whether a Neo4j instance allows a remote shell using the Neo4j REST API

Tested on Neo4j 2.0.3";

$VERSION = "0.1";

use strict;
use warnings;
BEGIN {
    use File::Basename;
    use lib dirname(__FILE__) . "/lib";
}
use HariSekhonUtils;
use Data::Dumper;
use JSON;
use LWP::Simple '$ua';

$ua->agent("Hari Sekhon $progname version $main::VERSION");

set_port_default(7474);

env_creds("Neo4j");

%options = (
    %hostoptions,
);
@usage_order = qw/host port/;

get_options();

$host  = validate_host($host);
$port  = validate_port($port);

vlog2;
set_timeout();

$status = "OK";

my $url_prefix = "http://$host:$port";
my $url = "$url_prefix/db/manage/server/jmx/domain/org.neo4j/instance%3Dkernel%230%2Cname%3DConfiguration";

my $content = curl $url, "Neo4j";
my $json;
try {
    $json = decode_json($content);
};
catch {
    quit "CRITICAL", "invalid json returned by Neo4j at '$url_prefix'. Try with -vvv to see full output";
};

vlog3(Dumper($json));
isArray($json) or quit "UNKNOWN", "output returned by Neo4j is not structured in output array. $nagios_plugins_support_msg_api";
defined($json->[0]->{"attributes"}) or quit "UNKNOWN", "'attributes' field not returned by Neo4j! $nagios_plugins_support_msg_api";
isArray($json->[0]->{"attributes"}) or quit "UNKNOWN", "attributes field returned by Neo4j is not an array as expected! $nagios_plugins_support_msg_api";

my $remote_shell_enabled;
foreach my $item (@{$json->[0]{"attributes"}}){
    defined($item->{"name"}) or quit "UNKNOWN", "'name' field not returned for items in 'attributes' by Neo4j! $nagios_plugins_support_msg_api";
    next unless $item->{"name"} eq "remote_shell_enabled";
    defined($item->{"value"}) or quit "UNKNOWN", "'value' field not returned for items in 'attributes' by Neo4j! $nagios_plugins_support_msg_api";
    $remote_shell_enabled = $item->{"value"};
    last;
}

defined($remote_shell_enabled) or quit "UNKNOWN", "failed to find remote_shell_enabled in output from Neo4j. $nagios_plugins_support_msg_api";

$msg = "Neo4j ";
if($remote_shell_enabled){
    critical;
    $msg .= "REMOTE SHELL ENABLED";
} else {
    $msg .= "remote shell is disabled";
}

quit $status, $msg;
