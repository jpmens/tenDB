#!/usr/bin/perl
#(@)tenDB.pl (C)2012 by Jan-Piet Mens <jpmens@gmail.com>
# Proof of concept; Use as you wish.

use strict;
use Net::LDAP;

my $ldapuri = [ qw(ldap://localhost ldap://hippo.ww.mens.de) ];
my $base = "ou=netDB, dc=mens, dc=de";
my $filter = "(&(objectClass=account)(uid=%s)(host=%s))";

die "Usage: $0 node-roles principal aclname" unless ($#ARGV eq 2);

my $princ	= $ARGV[1];
my $acl		= $ARGV[2];

# In my particular case: not a host principal => no access.

unless ($princ =~ /^host\//i) {
	print "no\n";
	exit 1;
}

(my $host = $princ) =~ s|host/||i;

my $ld = Net::LDAP->new($ldapuri) or die "$@";

my $msg = $ld->bind;
$msg->code && die $msg->error;

$msg = $ld->search(
		base => $base,
		filter => sprintf($filter, $acl, $host),
		attrs => [ 'uid' ],
	);
$msg->code && die $msg->error;

# foreach my $entry ($msg->entries) { $entry->dump; }

if ($msg->count() eq 1) {
	
	# Inform wallet-backend by replying as NetDB would
	# that the principal is authorized.

	print "user\n";		
	$ld->unbind;
	exit 0;
}

$ld->unbind;
exit 1;			# Inform wallet-backend: "not authorized"
