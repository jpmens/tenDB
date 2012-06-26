# tenDB Wallet-backend shim

## Huh?

[Wallet][1] is a system written by Russ Allbery to manage
secure data such as keytabs. Wallet contains support for
[Stanford's NetDB][2] but I neither need nor want NetDB (if
only because it requires an Oracle database; see also 
"[Is NetDB right for me?][2]"). This program
is a "shim" to emulate NetDB support in Wallet.

(tenDB is a half-cocked attempt at reversing the word NetDB.)

## wallet-backend and LDAP

While current versions of Wallet contain support for [using LDAP
as an ACL verifier][3], 
I wanted something a bit more flexible, which is why I wrote
this. Basically this program can be modified to look up an
ACL anywhere (RDBMS, NoSQL, flat files, etc.). For argument's
sake, let's look at a simple LDAP schema:

	dn: uid=acc01,ou=tenDB,o=example.net
	objectClass: account
	uid: acc01
	description: hosts in this ACL instance are allowed to request keytabs
	host: test.example.net
	host: workstation2.example.net

`uid` is the ACL _instance_ we're interested in in the `netdb` ACL scheme, and the
`host` attribute type contains the host principal authorized by the ACL.
If the host invoking Wallet client is contained in the 
LDAP entry for the ACL instance `acc01', using an LDAP filter like

	(&(objectClass=account)(uid=%s)(host=%s))

then the host is authorized.

## How this works

Add an [ACL to Wallet](http://www.eyrie.org/~eagle/software/wallet/api/acl.html):

	wallet acl add aclname netdb acc01

Wallet will invoke this program via _remctld_ (I've [discussed _remctl_ here](http://jpmens.net/2012/06/04/remctl-run-commands-on-remote-hosts-using-kerberos-authentication/).) If this program
exits with a status != 0, Wallet considers the ACL has not matched.
Otherwise, if it returns a string "user", "team", or "admin" 
(all of which are equivalent) the ACL matches.

Configure `remctl.conf` to contain something like this:

	# Called from Wallet (wallet-backend); should be safe to
	# have ANYUSER invoke this, but even safer to speicfy
	# the principal configured as $NETDB_REMCTL_PRINCIPAL in
	# wallet.conf
	netdb node-roles /etc/wallet/tenDB.pl ANYUSER

In Wallet's `wallet.conf`, configure

	$NETDB_REALM            = 'REALM';  # optional, see below
	$NETDB_REMCTL_HOST      = 'wallet-server.example.com';

	# Kerberos credential-cache required for Wallet to speak
	# to NetDB over remctl. Can be primed and kept alive with
	# k5start.
	$NETDB_REMCTL_CACHE     = '/etc/wallet/tenDB.ccache';


_tenDB.pl_ will be invoked with three (3) arguments:

1. The string "node-roles"
2. The principal name with which the Wallet client has authenticated;
   in this particular case, I'm interested in host/ principals only
   and will not authorize anything else. Change as needed.
   If Wallet has been configured with a `$NETDB_REALM' (in
   wallet.conf), then the specified realm will be stripped from the
   principal name. In other words:
   "@REALM" is stripped from argv[2] if
	$NETDB_REALM            = 'REALM';
   is configured in Wallet server's wallet.conf
3. The ACL "instance" for scheme "netdb". Suppose you've added
   an acl
	wallet acl add aclname netdb acc01
   then the "instance" is `acc01'.

As this program is invoked by remctld, it has access to the
following environment variables:

	REMOTE_HOST=wallet-server.example.net
	REMOTE_USER=host/wallet-server.example.net@REALM
	REMCTL_COMMAND=netdb
	REMOTE_ADDR=192.168.1.1

Wallet-backend expects this program to answer as if NetDB where replying, in other
words, if we find a single corresponding entry in LDAP (or whatever other
data store we're querying) we return the string "user" and exit with 0.

I mentioned it in a comment above: remember that `$NETDB_REMCTL_CACHE` must
be initialized and the keys therein must be renewed periodically. I suggest using
Russ Alberry's [k5start][4] for that.

  [1]: http://www.eyrie.org/~eagle/software/wallet/
  [2]: http://www.stanford.edu/group/networking/netdb/
  [3]: http://git.eyrie.org/?p=kerberos/wallet.git
  [4]: http://www.eyrie.org/~eagle/software/kstart/k5start.html

