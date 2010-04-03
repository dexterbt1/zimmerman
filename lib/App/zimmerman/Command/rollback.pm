package App::zimmerman::Command::rollback;
use strict;
use warnings;
use Carp;
use File::Copy ();
use File::Spec ();
use File::Path ();
use File::Basename ();
use File::Copy::Recursive ();
use Term::Prompt ();
use POSIX qw/strftime/;
use base qw/App::zimmerman::Command::_base/;


sub run {
    my ($self, $arga, $argh) = @_;

    # verify install_base (destination)
    my $install_base = $argh->{install_base} || $self->script->{install_base} || '';
    ($self->script->is_valid_install_base($install_base))
        or $self->help("! ERROR: install_base='$install_base' is not a valid writeable directory");

    # find the latest release config
    my $current_releaseconf;
    eval {
        $current_releaseconf = $self->script->get_current_release_config( install_base => $install_base );
    };
    if ($@) { 
        $self->help("! ERROR: error resolving current release: $@") 
    };

    # ensure proper rollback_id
    (defined $current_releaseconf->{rollback_id})
        or die "! ERROR: unable to find a previous release based on current release config";

    # find the previous release if available
    my $prev_releaseconf_path = $self->script->get_release_config_filepath( 
        install_base    => $install_base,
        release_id      => $current_releaseconf->{rollback_id},
    );
    my $prev_releaseconf = App::zimmerman::Config::Release->from_file( $prev_releaseconf_path );

    $self->script->chat("# ". ("-" x 60) . "\n");
    $self->script->chat("Current release_id:                ".$current_releaseconf->{release_id}."\n");
    $self->script->chat("Current release_origin:            ".$current_releaseconf->{release_origin}."\n");
    $self->script->chat("# ". ("-" x 60) . "\n");

    $self->script->chat("\nYou are about to ROLLBACK to a previous installation: \n");
    $self->script->chat("       release_id:        ".$prev_releaseconf->{release_id}."\n");
    $self->script->chat("       release_origin:    ".$prev_releaseconf->{release_origin}."\n");
    $self->script->chat("\n");
    my $cont = Term::Prompt::prompt(
        'y', 
        "Proceed with rollback?",
        "y/N",
        "N",
    );
    if (not $cont) {
        $self->script->chat("! ABORTED.\n");
        exit(1);
    }

    $self->script->chat("Updating release symlink ... ");

    $self->script->set_release_symlink(
        install_base    => $install_base,
        release_id      => $prev_releaseconf->{release_id},
        release_origin  => $prev_releaseconf->{release_origin},
    );

    $self->script->chat("OK\n");
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

Upon rollback, the symlink will be repointed to the appropriate release.

*REQUIRED. Run C<configure> to persist this setting.


=back

=cut
