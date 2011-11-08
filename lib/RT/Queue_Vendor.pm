package RT::Queue;
use strict;
use warnings;

sub Dependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::Dependencies($walker, $deps);

    # Queue role groups( Cc, AdminCc )
    my $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    $deps->Add( in => $objs );

    # Scrips
    $objs = RT::Scrips->new( $self->CurrentUser );
    $objs->LimitToQueue( $self->id );
    $deps->Add( in => $objs );

    # Templates (global ones have already been dealt with)
    $objs = RT::Templates->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Queue', VALUE => $self->Id);
    $deps->Add( in => $objs );

    # Custom Fields on things _in_ this queue (CFs on the queue itself
    # have already been dealt with)
    $objs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $objs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    my $cfs = $objs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $objs->Limit( ALIAS    => $cfs,
                  FIELD    => 'LookupType',
                  OPERATOR => 'STARTSWITH',
                  VALUE    => 'RT::Queue-' );
    $deps->Add( in => $objs );

    # Tickets
    $objs = RT::Tickets->new( $self->CurrentUser );
    $objs->_SQLLimit( FIELD => "Queue", VALUE => $self->Id );
    $objs->{allow_deleted_search} = 1;
    $deps->Add( in => $objs );
}

sub Serialize {
    my $self = shift;
    my %store = $self->SUPER::Serialize;
    $store{Name} = "$RT::Organization: $store{Name}"
        if $self->Name ne "___Approvals";
    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return if $importer->MergeBy( "Name", $class, $uid, $data );

    return 1;
}

1;
