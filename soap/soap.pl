use XMLRPC::Lite;
use Data::Dumper;
use strict;
use warnings;
use Encode;

my $confluence = XMLRPC::Lite->proxy('http://hdwiki/wiki/rpc/xmlrpc');
my $token = $confluence->call("confluence1.login", "wanglongzhi", "wanglongzhi")->result();
my $spaceKey = "RDC";

my $pageId = SOAP::Data->type( string => 584 );
#print "*** Admin User ***\n";
#print "getPermissions('TEST')\n";
#print Dumper($confluence->call("confluence1.getPermissions", $token, $spaceKey)->result()), "\n";

#print "getPermissionsForUser('TEST', 'admin')\n";
#print Dumper($confluence->call("confluence1.getPermissionsForUser", $token, $spaceKey, "admin")->result()), "\n";

#print "getPermissionsForUser('TEST', 'test')\n";
#print Dumper($confluence->call("confluence1.getPermissionsForUser", $token, $spaceKey, "test")->result()), "\n";

#print "getPagePermissions('Test Page')\n";
#print Dumper($confluence->call("confluence1.getPagePermissions", $token, $pageId)->result()), "\n";

#$confluence->call("confluence1.logout", $token);

my $page_title = encode('big5', '11Äê8ÔÂ·İ');
$token = $confluence->call("confluence1.login", "wanglongzhi", "wanglongzhi")->result();
print $token, "\n";
print Dumper($confluence->call("confluence1.getPage", $token, $spaceKey, $page_title)->result());

#print "*** Test User ***\n";
#print "getPermissions('TEST')\n";
#print Dumper($confluence->call("confluence1.getPermissions", $token, $spaceKey)->result()), "\n";

#print "getPermissionsForUser('TEST', 'admin')\n";
#print Dumper($confluence->call("confluence1.getPermissionsForUser", $token, $spaceKey, "admin")->result()), "\n";

#print "getPermissionsForUser('TEST', 'test')\n";
#print Dumper($confluence->call("confluence1.getPermissionsForUser", $token, $spaceKey, "test")->result()), "\n";

#print "getPagePermissions('Test Page')\n";
#print Dumper($confluence->call("confluence1.getPagePermissions", $token, $pageId)->result()), "\n";