package RT::ObjectTopic;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->TopicObj );

    my $obj = $self->ObjectType->new( $self->CurrentUser );
    $obj->Load( $self->ObjectId );
    $deps->Add( out => $obj );
}

1;
