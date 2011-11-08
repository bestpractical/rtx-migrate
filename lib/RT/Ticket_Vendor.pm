package RT::Ticket;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    # Links
    my $links = RT::Links->new( $self->CurrentUser );
    $links->Limit(
        SUBCLAUSE       => "either",
        FIELD           => $_,
        VALUE           => $self->URI,
        ENTRYAGGREGATOR => 'OR'
    ) for qw/Base Target/;
    $deps->Add( in => $links );

    # Tickets which were merged in
    my $objs = RT::Tickets->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'EffectiveId', VALUE => $self->Id );
    $objs->Limit( FIELD => 'id', OPERATOR => '!=', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Ticket role groups( Owner, Requestors, Cc, AdminCc )
    $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Ticket-Role' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Queue
    $deps->Add( out => $self->QueueObj );

    # Owner
    $deps->Add( out => $self->OwnerObj );
}

sub Serialize {
    my $self = shift;
    my %store = $self->SUPER::Serialize;

    my $obj = RT::Ticket->new( RT->SystemUser );
    $obj->Load( $store{EffectiveId} );
    $store{EffectiveId} = \($obj->UID);

    # Shove the ID back in, in case we want to preserve it during import
    $store{id} = $obj->Id;

    return %store;
}

1;
