zimmerman
=========

Zimmerman is a minimalist deployment management tool loosely inspired by
[Shipwright](http://search.cpan.org/perldoc?Shipwright) and 
[Capistrano](http://www.capify.org/).

Zimmerman is a derived German word which means `carpenter`.


Why yet another deployment system?
----------------------------------

First, this is *NOT* a Capistrano-clone in Perl nor a Shipwright-clone.
It is NEITHER a build-system that replaces `make`, `rake`, `CPAN`, etc.
As described, it heavily borrows concepts and ideas from these systems.
Zimmerman tries to be a simpler implementation with certain assumptions.

This project was started because a deployment management tool is needed to fit
a very specific company / workflow / codebase / team-training / time-cost-constraints. 
This unique combination led us to either shop/buy or build our own. After
a careful research, we opted the latter.

You may opt to checkout and test for yourself if Zimmerman can help you simplify 
your deployment.


Goals
-----

* DRY [Don't Repeat Yourself] style deployment
* Dependency tracking
* Upgrade / Rollback support
* On-the-fly pull and build - as opposed to a pre-packaged distribution
* Layered installs - installation under single $HOME
* Perl-centric - yet should be usable enough in non-perl projects


Requirements
------------

* perl 5.8.x
* CPAN
    * ExtUtils::Utils 6.31
    * [App::cpanminus](http://github.com/miyagawa/cpanminus)
    * File::Copy::Recursive
    * YAML
    * LWP
* GNU coreutils / GNU autotools
* Subversion client `svn`


Install
-------

* via github, as root try:
    
        cd /tmp
        git clone git://github.com/dexterbt1/zimmerman.git
        cd zimmerman
        perl Build.PL && ./Build && ./Build test && ./Build install


Meta
----

* Code: `git clone git://github.com/dexterbt1/zimmerman.git`
* Home: <http://github.com/dexterbt1/zimmerman/>
* Bugs: <http://github.com/dexterbt1/zimmerman/issues>


License
-------
Copyright 2010 Dexter Tad-y.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See <http://dev.perl.org/licenses/> for more information.


Author
------

Dexter B. Tad-y <dtady@cpan.org>

