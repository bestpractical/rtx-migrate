package RT::Topic;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);
    $deps->Add( out => $self->ParentObj );
    $deps->Add( in => $self->Children );

    my $obj = $self->ObjectType->new( $self->CurrentUser );
    $obj->Load( $self->ObjectId );
    $deps->Add( out => $obj );
}

1;
