package RT::Topic;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);
    $deps->Add( out => $self->ParentObj );
    $deps->Add( in  => $self->Children );
    $deps->Add( out => $self->Object );
}

sub Object {
    my $self  = shift;
    my $Object = $self->__Value('ObjectType')->new( $self->CurrentUser );
    $Object->Load( $self->__Value('ObjectId') );
    return $Object;
}

1;
