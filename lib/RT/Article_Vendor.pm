package RT::Article;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    # Links
    my $links = RT::Links->new( $self->CurrentUser );
    $links->Limit(
        SUBCLAUSE       => "either",
        FIELD           => $_,
        VALUE           => $self->URI,
        ENTRYAGGREGATOR => 'OR'
    ) for qw/Base Target/;
    $deps->Add( in => $links );

    $deps->Add( out => $self->ClassObj );
    $deps->Add( in => $self->Topics );
}

sub PostInflate {
    my $self = shift;

    $self->__Set( Field => 'URI', Value => $self->URI );
}

1;
