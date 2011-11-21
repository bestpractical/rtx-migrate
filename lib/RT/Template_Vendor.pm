package RT::Template;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->QueueObj );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    if ($data->{Queue} == 0) {
        my $obj = RT::Template->new( RT->SystemUser );
        $obj->LoadGlobalTemplate( $data->{Name} );
        if ($obj->Id) {
            $importer->Resolve( $uid => ref($obj) => $obj->Id );
            return;
        }
    }

    return 1;
}

1;
