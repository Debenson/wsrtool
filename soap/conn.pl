use SOAP::Lite;
use Data::Dumper;
use Encode;
use URL::Encode;

my $user = 'wanglongzhi';
my $password = 'wanglongzhi';
my $loginURI = "http://hdwiki/wiki/rpc/soap-axis/confluenceservice-v1?wsdl";
my $space_key = "RDC";
my $title = "11年8月份";

my $loginsoap = SOAP::Lite->proxy($loginURI)-> uri($loginURI);

#START
print "\n";

#get session
my $session = $loginsoap->login($user, $password)->result;
print "session is: " . $session . "\n";

my $page = $loginsoap->getPage($session, $space_key, '11年8月份')->result;
print Dumper($page);

# logout
my $logout = $loginsoap->logout($session)->result;
print "logging out: " . $logout . "\n";

#END
print "\n";
exit;