package RT::CustomField;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    $deps->Add( out => $self->BasedOnObj )
        if $self->BasedOnObj->id;

    my $applied = RT::ObjectCustomFields->new( $self->CurrentUser );
    $applied->LimitToCustomField( $self->id );
    $deps->Add( in => $applied );

    $deps->Add( in => $self->Values ) if $self->ValuesClass eq "RT::CustomFieldValues";
}

1;
