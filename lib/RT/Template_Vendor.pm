package RT::Template;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->QueueObj ) if $self->QueueObj->Id;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    my $obj = RT::Template->new( RT->SystemUser );
    if ($data->{Queue} == 0) {
        $obj->LoadGlobalTemplate( $data->{Name} );
    } else {
        $obj->LoadQueueTemplate( Queue => $data->{Queue}, Name => $data->{Name} );
    }

    if ($obj->Id) {
        $importer->Resolve( $uid => ref($obj) => $obj->Id );
        $importer->MergeValues( $obj, $data ) if $importer->{Overwrite};
        return;
    }

    return 1;
}

1;
