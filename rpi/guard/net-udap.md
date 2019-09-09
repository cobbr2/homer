Re: [slim] Net::UDAP - SqueezeBox Receiver configuration tool
2016-11-20 Thread cobbr2

I sent you a pint or two.  I used my Ubuntu laptop this time; had no
trouble with that cpan command and immediately resuscitated the
receiver. Hallelujah! Wasn't aware of the need to run that `cpan`
command; totally helpful. And I'm always happier with git than svn :)

robinbowes wrote: 
> Something like this should work:
> 
> > 
Code:

  >   > 
  > $ git clone https://github.com/robinbowes/net-udap.git
  > $ cd net-udap
  > $ cpan Log::StdLog Term::Shell Class::Accessor IO::Interface::Simple
  > $ ./scripts/udap_shell.pl
  > UDAP> discover
  > info: <<< Broadcasting adv_discovery message to MAC address 
00:00:00:00:00:00 on 255.255.255.255
