package App::zimmerman;

use warnings;
use strict;

=head1 NAME

App::zimmerman - minimalist deployment management tool

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    zim configure set --repo=svn://12.34.56.78/main 
    zim configure set --site_branch=trunk
    zim configure set --install_base=$HOME
    zim configure set --site=OurSite
    zim deploy
    zim help

Please see L<http://github.com/dexterbt1/zimmerman/>.

=head1 AUTHOR

Dexter Tad-y, C<< <dtady at cpan.org> >>

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc App::zimmerman 


You can also look for information at:

=over 4

=item * Code: 

C<git clone git://github.com/dexterbt1/zimmerman.git>

=item * Home: 

L<http://github.com/dexterbt1/zimmerman/>

=item * Bugs: 

L<http://github.com/dexterbt1/zimmerman/issues>


=back


=head1 LICENSE AND COPYRIGHT

Copyright 2010 Dexter Tad-y.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;

__END__
