package App::zimmerman::Command::rollback;
use strict;
use warnings;
use Carp;
use File::Copy;
use File::Spec;
use File::Path;
use File::Basename;
use File::Copy::Recursive;
use POSIX qw/strftime/;
use base qw/App::zimmerman::Command::_base/;


sub run {
    my ($self, $arga, $argh) = @_;

    # verify install_base (destination)
    my $install_base = $argh->{install_base} || $self->script->{install_base} || '';
    ($self->script->is_valid_install_base($install_base))
        or $self->help("! ERROR: install_base='$install_base' is not a valid writeable directory");

    # find the latest release config
    my $current_release_config;
    eval {
        $current_release_config = $self->script->get_current_release_config(
            install_base => $install_base,
        );
    };
    if ($@) { 
        $self->help("! ERROR: error resolving current release: $@") 
    };

    # find the previous release if available

    die "! ERROR: not implemented yet";
}


sub help {
    my ($self, $message) = @_;
    my $u = $self->script->usage('rollback');
    if (defined $message) {
        $u = join("\n",$message,'',$u);
    }
    $self->pod_help(__FILE__, "$u\n");
}


1;

__END__

=head1 NAME

rollback - restores to a previously deployed release

=head1 OPTIONS

=over 4

=item --install_base

The base path to where deployed sites will be anchored.
Each deploy will create a new directory under C<$install_base/releases/xxxxxxx>.
A symlink C<$install_base/current> will always point to the
last deployed release.

Upon rollback, and depending on the steps / date specified, the symlink 
will be repointed to the appropriate release.

*REQUIRED. Run C<configure> to persist this setting.

=item --steps=N

Specified number of steps to rollback, i.e. how many releases. 

Defaults to 1 step (which means the last release deployed).

*OPTIONAL. Either this is specified OR a --date is specified.

=item --to_earliest_date=YYYY-mm-dd 



=back

=cut
