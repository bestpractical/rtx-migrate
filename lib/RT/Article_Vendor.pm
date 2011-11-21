package RT::Article;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);
    $deps->Add( out => $self->ClassObj );
    $deps->Add( in => $self->Topics );
}

sub PostInflate {
    my $self = shift;

    $self->__Set( Field => 'URI', Value => $self->URI );
}

1;
