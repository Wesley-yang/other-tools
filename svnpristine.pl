#!/usr/bin/perl

use LWP::UserAgent;
use DBI;
use File::Temp qw/tempfile tempdir/;

# Read roots
sub readroots
{
   my ($dbh) = @_;
   my @ROOTS;
   my $roots = $dbh->prepare("select id,local_abspath from WCROOT");
   $roots->execute;

   while (my @i = $roots->fetchrow_array())
   {
      push(@ROOTS,{'id'=>$i[0], 'path'=>$i[1]});
   }
   return @ROOTS;
}

# Read nodes
sub readnodes
{
   my ($dbh) = @_;
   my @NODES;
   my $nodes = $dbh->prepare("select wc_id, local_relpath, checksum, kind from NODES");
   $nodes->execute;

   while (my @i = $nodes->fetchrow_array())
   {
      push(@NODES,{'id'=>$i[0], 'path'=>$i[1], 'sum'=>$i[2], 'kind'=>$i[3]});
   }
   return @NODES;
}

$File::Temp::KEEP_ALL=0;

my @ROOTS;;
my @NODES;

# grab the database file

my $target=$ARGV[0];

my $svnurl="http://$ARGV[0]/.svn/wc.db";

my $ua=LWP::UserAgent->new;
$ua->agent("SVNScanner/1.0");

my $request=HTTP::Request->new(GET => $svnurl);
my $result=$ua->request($request);

if ($result->status_line !~ /^200 .*/) {
   die "Could not get svn database";
}

my ($dbfileh, $dbfilen) = tempfile();
print "$dbfilen\n";
print $dbfileh $result->content;
close $dbfileh;

# open database
my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfilen","","");

@ROOTS=readroots($dbh);
@NODES=readnodes($dbh);

# Now to read it all from pristine
# create output dir
my $server=$ARGV[0];
mkdir $server;
foreach my $node (@NODES)
{
   if ($node->{'kind'} eq "dir")
   {
      mkdir "$server/$node->{'local_relpath'}";
   }
   else
   {
      my $checksum=substr($node->{'sum'}, 6);
      my $twochars=substr($checksum, 0, 2);
      my $svnurl="http://$server/.svn/pristine/$twochars/$checksum.svn-base";

      my $fua=LWP::UserAgent->new;
      $fua->agent("SVNScanner/1.0");

      my @brokenup=split(/\//,$node->{'path'});
      my $pathstr="$server/";
      for (my $i=0;$i < $#brokenup; $i++)
      {
         $pathstr="$pathstr$brokenup[$i]/";
         mkdir "$pathstr";
      }

      my $frequest=HTTP::Request->new(GET => $svnurl);
      my $fresult=$fua->request($frequest);
      print "grabbing $server/$node->{'path'} from $svnurl\n";
      open $fh,">$server/$node->{'path'}";
      print $fh $fresult->content;
      close $fh;
   }
}
