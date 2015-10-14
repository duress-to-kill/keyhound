# Keyhound
A script for managing SSH keyed logins between several (or many) hosts.

## Introduction
I operate a file server, two general-use work computers, a VPS, and a raspberry pi that pulls duty as a micro-server. I also have several work machines that I use heavily but don't own.

Needless to say, I have a lot of SSH keys to keep track of. I started keeping a copy of all of my pubkeys in a git repository that I host in my own private gitolite instance. This is convenient, I highly recommend it if your computing environment is complicated and highly interconnected like mine.

If you do, it may occur to you that it would be even better if you had a portable little script in that repo that could handle managing your SSH authorized_keys file for you, to make keeping track of what's installed where a little easier.

As it turns out, in this eventuality I've saved you the effort of actually writing said script. keyhound will happily do it for you.

## Setup
Keyhound is pretty simple. It has just a few expectations.

Mostly, it assumes that you have a directory where you collect all your SSH public keys, and you use something (like git, or rsync) to sync a local copy of this directory to each host where you want to use keyhound. I've populated pubkeys/ with some dummy keys for testing. All of the corresponding private keys were immediately deleted, so the pubkeys are harmless. Of course, it would be immensely irresponsible of you to trust me about that, but you can specify a dummy authorized_keys file for testing purposes.

It also assumes your pubkeys follow the general naming scheme of "id_rsa.pub.name", where "name" corresponds to a string that appears in the key's comment (this normally defaults to "username@host", according to wherever the key was initially created). In my environment, "name" is equivalent to the name of the host that that public key is associated with.

It also assumes you have several general classes of security, which keyhound calls "rings" because I though it sounded cool. Each of your public keys will be assigned into a ring. When you run keyhound, you will specify a security ring, and all the keys of that ring or lower will be installed into that account's authorized_keys file. These assignments are made in a variable definition at the top of the script. An example is present in the file, and a step-by-step is given below.

So when you try to SSH to an account that's managed by keyhound, using a key that keyhound recognizes, this will be allowed if the key you're using belongs to an equal or lower (i.e. "inner", more secure) ring than the account does. I.e., a ring 0 key will get you into any keyhound-managed account. A ring 3 account can be accessed by any ring 0, 1, 2, or 3 key.

## Configuration
You'll want to tell keyhound which keys it should expect to use, by assiging each such key into one or more index of the bash array "KEYS\_LEVEL". Each index of "KEYS\_LEVEL" is expected to be a whitespace-separated list of the keys that belong in the security ring corresponding to that index.

Other configurables appear at the top of the keyhound.sh script, with comments. In brief, the things that can be configured include:
* LOWRING                - The index of the least-privileged security ring that keyhound will expect to find.
* KEYDIR                 - The directory where keyhound will look for your collection of pubkeys. This defaults to a directory called pubkeys, which is expected to be located in the same place as the keyhound script itself.
* AUTHORIZED\_KEYS\_FILE - The path to the file where your SSH server will look to find keys, when you try to log into this account from elsewhere. Defaults to the usual ~/.ssh/authorized_keys

## Example Usage
Imagine I have four networked computer accounts that I regularly use. Each account has its own RSA public-private keypair. I have made a duplicate of the public key from each of the four keypairs, and collected them in a directory.

Suppose my four accounts are as follows:
* My login on my laptop, "amanita", which I carry around and trust implicitly.
* My login on my personal workstation at home, "galerina". It's pretty secure, and doesn't allow remote access.
* My login on my VPS, "chanterelle", which no one else uses. It runs a lot of public services.
* My login on my work host, "chicken-of-the-woods". I don't administrate this account, or the machine i use it on.

I decide that amanita and galerina should be in security ring 0. They don't run any services, they don't allow any kind of remote login, and I patch them regularly. I also do most of my personal work from these machines, so I want them to be able to get into everything.

Chanterelle I trust a little less. I still manage it myself, but it has 24 hour uptime and is publicly exposed, plus it runs a lot of services that may have security zero-day notifications form time to time. I'll put chanterelle in ring 1.

Chicken-of-the-woods is a terrible name for a host. It's also a machine I only trust as much as I have to to do my job. I don't manage it, and other users can log in on it. My account info is mounted via NFS and my login info is exchanged to an LDAp server over the intranet. And it's possible that due to unforseen circumstances or simple forgetfulness, I may lose control of my files (including my key) here one day. This machine goes into the outermost security ring I have (in this case, ring 2.)

Armed with this info, I edit keyhound.sh and assign these names into the appropriate rings: 
```
KEYS_LEVEL[0]="amanita
  galerina"
KEYS_LEVEL[1]="${KEYS_LEVEL[0]}
  chanterelle"
KEYS_LEVEL[2]="${KEYS_LEVEL[1]}
  chicken-of-the-woods"
```
Note that keyhound assumes that if you want outer rings to imply inner rings, that you'll set up your assignments accordingly, as shown here.

Now keyhound is ready to go. I can rsync (or git clone) this directory to any host I want, and use keyhound to load my SSH authorized_keys file with all the keys in whichever ring I specify.

For example:
```
./keyhound.sh -i 1
```
The above command will install ring 1 keys (chanterelle, as well as the implied ring 0 keys for amanita and galerina). Now I can ssh from chanterelle, amanita, and galerina to the account where I just ran this command.
