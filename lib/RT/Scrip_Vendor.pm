package RT::Scrip;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->ScripConditionObj );
    $deps->Add( out => $self->ScripActionObj );
    $deps->Add( out => $self->QueueObj );
    $deps->Add( out => $self->TemplateObj );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    if ($data->{Queue} == 0) {
        my $obj = RT::Scrip->new( RT->SystemUser );
        $obj->LoadByCols( Queue => 0, Description => $data->{Description} );
        if ($obj->Id) {
            $importer->Resolve( $uid => ref($obj) => $obj->Id );
            return;
        }
    }

    return 1;
}

1;
