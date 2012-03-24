@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!perl
#line 15
#################################################################################################################
# Weekly Status Report Tool(WSR)
# Debenson - 2011.08.22 - v0.1
# This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
# This program is distributed in the hope that it will be useful, but without any warranty; without even the 
# implied warranty of merchantability or fitness for a particular purpose.
# Remote API Specification: http://confluence.atlassian.com/display/CONFDEV/Confluence+XML-RPC+and+SOAP+APIs
# Perl XML-RPC Client: http://confluence.atlassian.com/display/DISC/Perl+XML-RPC+client
################################################################################################################
use Confluence;
use strict;
use warnings;
use MIME::Base64;
use Encode;
use File::Slurp;
use Text::Trim;
use Config::Simple;
use utf8;
use Getopt::Long;
use HTML::FormatText::WithLinks;
use Date::Calc qw(Days_in_Month Day_of_Week Add_Delta_Days);
use constant CFG_FILE_NAME => 'wsr.ini';

binmode(STDIN, ':encoding(utf8)');
binmode(STDOUT, ':encoding(utf8)');
binmode(STDERR, ':encoding(utf8)');
Confluence::setRaiseError(1);
Confluence::setPrintError(1);

# global variables
my $gbl_url = '';
my $gbl_space_key = '';
my $gbl_parent_page = '';
my $gbl_page_title = '';
my $gbl_usr = '';
my $gbl_pwd = '';
my $gbl_cfg;
 
# rock now
main();

# entrance of this program 
sub main {	
	my ($att, $help, $period);
	GetOptions(
		'u=s', \$gbl_usr, 
		'p=s', \$gbl_pwd, 		
		'r=s', \$gbl_url,
		'k=s', \$gbl_space_key,
		'f=s', \$gbl_parent_page,
		't=s', \$period,
		'h', \$help,
	);		

	if( $help ) {
		show_help();
		return;
	}

	$att = shift @ARGV;
	if( not $att ) {
		print 'wsr. file name CANNOT be empty, try -h';
		return;
	}	
	init_gbl_val();	
	if( not $gbl_usr ) {
		print 'usr name cannot auto initialized implict, try -u';
		return;
	}
	if( not $gbl_url ) {
		print 'rpc uri cannot auto initialized implict, try -r';
		return;
	}
	if( not $gbl_space_key ) {
		print 'space key cannot auto initialized implict, try -k';
		return;
	}
	$period = guess_period($att) unless $period;
	if( not $period ) {
		print 'WSR period cannot auto initialized implict, try -t';
		return;
	}
	$gbl_page_title = parse_page_title($period);
	if( not $gbl_page_title ) {
		print 'WSR page title cannot auto initialized implict';
		return;
	}

	proc($att, $period);
	save_rt_cfg();
}

# upload WSR and update page
sub proc {
	my ($wsr_file, $period) = @_;	
	my $wiki = new Confluence($gbl_url, $gbl_usr, ($gbl_pwd? $gbl_pwd : $gbl_usr));
	die Confluence::lastError() unless $wiki;
	#$Confluence::CONFLDEBUG=1; 		

	my $page;
	eval {
		$page = $wiki->getPage($gbl_space_key, $gbl_page_title);
	};
	if( $@ and not $page ) {
		print "Cannot find the specified page, create it?[y/n]: ";
		$_ = <>;
		chomp;		
		$page =  create_new_page($wiki, $period) if /^y$/i;					
	}
	die "Cannot find the specified page" unless $page;

	my $usr_cn_name = get_usr_cn_name($gbl_usr);
	die Confluence::lastError() unless 
		update_page($wiki, $page, $usr_cn_name, $wsr_file, $period);

	$wiki->logout();
}

# parse wsr page
sub update_page {
	my ($wiki, $page, $usr_cn_name, $wsr_file, $period) = @_;
	my $page_info = parse_page($wiki, $page);
	my @periods = @{$page_info->{periods}};	

	my @st_end = split /~/, $period;	
	my $index = -1;
	foreach(0 .. $#periods) {
		my @tmp = split /~/, $periods[$_];
		if( $st_end[0] >= $tmp[0] and $st_end[0] <= $tmp[1] ) {		
			$index = $_;
			last;
		}
	}
	die 'Cannot find WSR period' unless $index >= 0;
	foreach my $cur_wsr (@{$page_info->{content}}) {		
		if( $cur_wsr->{name} eq $usr_cn_name ) {
			${$cur_wsr->{wsr}}[$index] = "[$usr_cn_name\_$period|^" . decode('gbk', $wsr_file) . "]";			
			die Confluence::lastError() unless add_wsr_att($wiki, $page, $wsr_file);
			last;
		}
	}	

	my $content = page_to_str($page_info);	
	my $page_modified = {
		id => $page->{id},
        space => $gbl_space_key,
        title => $page->{title},
        content => $content,
		parentId => $gbl_parent_page,
		version => $page->{version},
	};   
    return $wiki->updatePage($page_modified);	
}

# convert page to obj.
sub parse_page {
	my ($wiki, $page) = @_;
	my %page_info;
	my $row = 0;
	my @headers;
	my $sep = 'CB406410-6C08-1014-B928-DE608C03195D';
	my $hf = HTML::FormatText::WithLinks->new(); # html formater
	for my $line (split "\n", $page->{content}) {		
		$line = trim($line);
		if( $row == 0 ) {
			map{ push @headers, trim($_) if /\d+~\d+/ } split '\|\|', $line;							
			$page_info{periods} = \@headers;
		} else {			
			# to be improved
			$line =~ s/\[([^\]]*)\|([^\]]*)\]/[$1$sep$2]/ig;	
			my @columns;			
			map{ 
				s/$sep/\|/g;  
				push @columns, trim($_); 
			} split /\|/, $line;

			if($#columns > 1) {
				my %cur_wsr;
				$cur_wsr{html_name} = trim($columns[1]);
				
				my $html_name = $hf->parse($columns[1]);
				$html_name =~ s/\s|\*//g;
				$cur_wsr{name} = $html_name;								
				
				my @tmp = @columns[2..$#columns];
				$cur_wsr{wsr} = \@tmp;

				# init. names
				$page_info{content} = [] unless $page_info{content};
				push @{$page_info{content}}, \%cur_wsr;				
			}
		}
		$row++;
	}
	
	# print Dumper(%page_info);
	return \%page_info;
}

# convert page obj. to string
sub page_to_str {
	my $page = shift;	
	my $str = '';
	$str .= '|| 人员名称 || ' . (join ' || ', @{$page->{periods}}) . ' ||';		
	foreach (@{$page->{content}}) {
		$str .= "\n| " . $_->{html_name} . ' | ' . (join ' | ', @{$_->{wsr}}) . '|';
	}			
	return $str;
}

# upload WSR attachment.
sub add_wsr_att {	
	my ($wiki, $page, $filename) = @_;	
	my $data = read_file($filename, binmode => ':raw');  #encode file name
	my $escaped_data = new RPC::XML::base64($data); 
	my $metadata = {
		fileName => decode('gbk', $filename),
		contentType => "application/vnd.ms-excel",
		comment => 'Automatic uploaded by Weekly Status Report Tool(WSR): ' . decode('gbk', $filename), 
	}; 
	return $wiki->addAttachment($page->{id}, $metadata, $escaped_data); 	
}

# init. global variables
sub init_gbl_val {
	# init cfg. 
	restore_def_cfg() unless -e CFG_FILE_NAME;
	$gbl_cfg = new Config::Simple(filename => CFG_FILE_NAME, syntax => 'ini');	
	
	# init global variables.
	if (not $gbl_url and $gbl_cfg->param('RPC_XML_URI') 
		and ref($gbl_cfg->param('RPC_XML_URI')) ne 'ARRAY') {
		$gbl_url = decode('utf-8', $gbl_cfg->param('RPC_XML_URI'));
	}		
	if (not $gbl_space_key and $gbl_cfg->param('SPACE_KEY') 
		and ref($gbl_cfg->param('SPACE_KEY')) ne 'ARRAY') {
		$gbl_space_key = decode('utf-8', $gbl_cfg->param('SPACE_KEY'));
	}
	if (not $gbl_parent_page and $gbl_cfg->param('PARENT_PAGE') 
		and ref($gbl_cfg->param('PARENT_PAGE')) ne 'ARRAY') {
		$gbl_parent_page = decode('utf-8', $gbl_cfg->param('PARENT_PAGE'));
	}
	if (not $gbl_usr and $gbl_cfg->param('login.usr') 
		and ref($gbl_cfg->param('login.usr')) ne 'ARRAY') {		
		$gbl_usr = decode('utf-8', $gbl_cfg->param('login.usr'));	
	}	
	if (not $gbl_pwd and $gbl_cfg->param('login.pwd') 
		and ref($gbl_cfg->param('login.pwd')) ne 'ARRAY') {
		$gbl_pwd = decode_base64($gbl_cfg->param('login.pwd'));
	}	
}

# restore default cfg. values
sub restore_def_cfg {	
	$gbl_cfg = new Config::Simple(syntax => 'ini');	

	# block default
	$gbl_cfg->param('RPC_XML_URI', 'http://hdwiki/wiki/rpc/xmlrpc');
	$gbl_cfg->param('SPACE_KEY', 'RDC');
	$gbl_cfg->param('PARENT_PAGE', '102400014');
	$gbl_cfg->param('LAST_MODIFIED', scalar(localtime));
	
	# block usrs
	my %users = (
		'gaoxiaoxia' => '高小霞',	
		'gebing' => '葛并',	
		'gonghaiwei' => '宫海威',	
		'guanxiaobao' => '管小宝',	
		'guilinsong' => '桂林松',	
		'guochunrong' => '郭春荣',	
		'guolei' => '郭磊',	
		'licuicui' => '李翠翠',	
		'niliang' => '倪亮',	
		'tianlei' => '田磊',	
		'wanglongzhi' => '王龙志',	
		'wangweijun' => '王伟俊',	
		'wangxiaoming' => '王小明',	
		'yaoyuan' => '姚远',	
		'zhongjingjing' => '仲晶晶',	
		'zhuyiguo' => '朱仪国',	
	);
	foreach (keys %users) {
		$gbl_cfg->param('usrs.' . $_, encode('utf-8', $users{$_}));
	}
	
	# block login
	$gbl_cfg->param('login.usr', '');	
	$gbl_cfg->param('login.pwd', '');	

	$gbl_cfg->write(CFG_FILE_NAME);
}

# convert login name to usr name
sub get_usr_cn_name {
	my $usr = shift;
	return decode('utf-8', $gbl_cfg->param("usrs.$usr"));
}

# save runtime cfg.
sub save_rt_cfg {
	$gbl_cfg->param('login.usr', $gbl_usr);
	$gbl_cfg->param('login.pwd', $gbl_pwd? encode_base64($gbl_pwd) : '');
	$gbl_cfg->param('LAST_MODIFIED', scalar(localtime));
	$gbl_cfg->save;
}

# get page title via wsr period
sub parse_page_title {
	my $period = shift;	
	if( $period =~ /^(\d{4})(\d{2})/ ) {
		return sprintf("%02d年%d月份", $1 % 100, $2);
	} else {
		return undef;	
	}
}

# create a blank wsr page
sub create_new_page {
	my ($wiki, $period) = @_;

	my $year;
	my $mon;
	if( $period =~ /^(\d{4})(\d{2})/g ) {
		$year = $1;
		$mon = $2;
	} else {
		die "invalid period: $period";
	}
	my $periods = get_month_periods($year, $mon);	
	my $content = '';
	$content .= '|| 人员名称 || ' . (join ' || ', @{$periods}) . ' ||';		
	my $usrs = $gbl_cfg->param(-block=>'usrs');	
	foreach(sort keys %{$usrs} ) {
		$content .= "\n| *" . decode('utf-8', $usrs->{$_}) . "*" . (' | ' x ($#{$periods}+1)) . '|';
	}	
	my $page = {		
        space => $gbl_space_key,
        title => $gbl_page_title,
        content => $content,
		parentId => $gbl_parent_page,		
		
	};  		
	return $wiki->updatePage($page);		
}

sub get_month_periods {
	my ($year, $mon) = @_;
	
	my $days = Days_in_Month($year, $mon);	
	my $first_mon_day;
	for (1 .. $days ) {
		if( Day_of_Week($year, $mon, $_) == 1 ) {
			$first_mon_day = $_;			
			last;
		}
	}
	
	my @periods;	
	my $friday;
	while( $first_mon_day <= $days ) {
		my $start_period = sprintf("%4d%02d%02d", $year, $mon, $first_mon_day);		
		($year, $mon, $friday) = Add_Delta_Days($year, $mon, $first_mon_day, 4);
		my $end_period = sprintf("%4d%02d%02d", $year, $mon, $friday);
		my $period = sprintf("%s~%s", $start_period, $end_period);
		push @periods, $period;
		$first_mon_day += 7;	
	}

	return \@periods;
}

# try to guess period by att. file name
sub guess_period {
	my $att = shift;	
	my $period = '';
	if( $att =~ /(\d{4}|\d{2})\S*(\d{2})\S*(\d{2})\S+(\d{4}|\d{2})\S*(\d{2})\S*(\d{2})/ ) {		
		my $y = $1%100 + 100 + 1900;
		$period = $y.$2.$3.'~'.$y.$5.$6;				
	} 
	return $period;
}

sub show_help {
print <<EOF;
Weekly Status Report Tool(WSR) v0.1
Usage: WSR [-u] [-p] [-r] [-k] [-f] [-t] [-h] <your wsr. file>
  -u                  hdwiki usr name
  -p                  hdwiki password
  -r                  hdwiki xml rpc url, as http://hdwiki/wiki/rpc/xmlrpc 
  -k                  target space key as RDC
  -f                  parent page id, see hdwiki
  -t                  week period, as 2011.09.05~2011.09.10
  -h                  show this message
EOF
}
__END__
:endofperl
