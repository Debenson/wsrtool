#!/usr/bin/perl
use strict;
use warnings;
use RPC::JSON;

my $user = 'wanglongzhi';
my $password = 'wanglongzhi';
my $url = "http://hdwiki/wiki/rpc/soap-axis/confluenceservice-v1?wsdl";
my $space_key = "RDC";
my $title = "11Äê8ÔÂ·İ";

 my $jsonrpc = RPC::JSON->new($url);

my $token = $jsonrpc->login($user, $password);

 print $token;

# Imports a geocode(['address']) method:
#$jsonrpc->getPage()('1600 Pennsylvania Ave');