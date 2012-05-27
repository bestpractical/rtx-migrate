package RT::Record;
use strict;
use warnings;

sub UID {
    my $self = shift;
    return undef unless defined $self->Id;
    return "@{[ref $self]}-$RT::Organization-@{[$self->Id]}";
}

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;
    for my $col (qw/Creator LastUpdatedBy/) {
        if ( $self->_Accessible( $col, 'read' ) ) {
            next unless $self->$col;
            my $obj = RT::Principal->new( $self->CurrentUser );
            $obj->Load( $self->$col );
            $deps->Add( out => $obj->Object );
        }
    }

    # Object attributes, we have to check on every object
    my $objs = $self->Attributes;
    $deps->Add( in => $objs );

    # Transactions
    if (   $self->isa("RT::Ticket")
        or $self->isa("RT::User")
        or $self->isa("RT::Group")
        or $self->isa("RT::Article")
        or $self->isa("RT::Queue") )
    {
        $objs = RT::Transactions->new( $self->CurrentUser );
        $objs->Limit( FIELD => 'ObjectType', VALUE => ref $self );
        $objs->Limit( FIELD => 'ObjectId', VALUE => $self->id );
        $deps->Add( in => $objs );
    }

    # Object custom field values
    if (   $self->isa("RT::Transaction")
        or $self->isa("RT::Ticket")
        or $self->isa("RT::User")
        or $self->isa("RT::Group")
        or $self->isa("RT::Queue")
        or $self->isa("RT::Article") )
    {
        $objs = $self->CustomFieldValues; # Actually OCFVs
        $objs->{find_expired_rows} = 1;
        $deps->Add( in => $objs );
    }

    # ACE records
    if (   $self->isa("RT::Group")
        or $self->isa("RT::Class")
        or $self->isa("RT::Queue")
        or $self->isa("RT::CustomField") )
    {
        $objs = RT::ACL->new( $self->CurrentUser );
        $objs->LimitToObject( $self );
        $deps->Add( in => $objs );
    }
}

sub Serialize {
    my $self = shift;
    my %args = (
        Methods => {},
        @_,
    );
    my %methods = (
        Creator       => "CreatorObj",
        LastUpdatedBy => "LastUpdatedByObj",
        %{ $args{Methods} || {} },
    );

    my %values = %{$self->{values}};

    my %ca = %{$self->_ClassAccessible || $self->_CoreAccessible};
    my @cols = grep {exists $values{lc $_} and defined $values{lc $_}} keys %ca;

    my %store;
    $store{$_} = $values{lc $_} for @cols;

    # Un-encode things with a ContentEncoding for transfer
    if ($ca{ContentEncoding} and $ca{ContentType}) {
        my ($content_col) = grep {exists $ca{$_}} qw/LargeContent Content/;
        $store{$content_col} = $self->$content_col;
        delete $store{ContentEncoding};
    }
    return %store unless $args{UIDs};

    # Use FooObj to turn Foo into a reference to the UID
    for my $col ( grep {$store{$_}} @cols ) {
        my $method = $methods{$col};
        if (not $method) {
            $method = $col;
            $method =~ s/(Id)?$/Obj/;
        }
        next unless $self->can($method);

        my $obj = $self->$method;
        next unless $obj and $obj->isa("RT::Record");
        $store{$col} = \($obj->UID);
    }

    # Anything on an object should get the UID stored instead
    if ($store{ObjectType} and $store{ObjectId} and $self->can("Object")) {
        delete $store{$_} for qw/ObjectType ObjectId/;
        $store{Object} = \($self->Object->UID);
    }

    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    my $ca = $class->_ClassAccessible || $class->_CoreAccessible;
    my %ca = %{ $ca };

    if ($ca{ContentEncoding} and $ca{ContentType}) {
        my ($content_col) = grep {exists $ca{$_}} qw/LargeContent Content/;
        if (defined $data->{$content_col}) {
            my ($ContentEncoding, $Content) = $class->_EncodeLOB(
                $data->{$content_col},
                $data->{ContentType},
            );
            $data->{ContentEncoding} = $ContentEncoding;
            $data->{$content_col} = $Content;
        }
    }

    if ($data->{Object} and not $ca{Object}) {
        my $ref_uid = ${ delete $data->{Object} };
        my $ref = $importer->Lookup( $ref_uid );
        if ($ref) {
            my ($class, $id) = @{$ref};
            $data->{ObjectId} = $id;
            $data->{ObjectType} = $class;
        } else {
            $data->{ObjectId} = 0;
            $data->{ObjectType} = "";
            $importer->Postpone(
                for => $ref_uid,
                uid => $uid,
                column => "ObjectId",
                classcolumn => "ObjectType",
            );
        }
    }

    for my $col (keys %{$data}) {
        if (ref $data->{$col}) {
            my $ref_uid = ${ $data->{$col} };
            my $ref = $importer->Lookup( $ref_uid );
            if ($ref) {
                my (undef, $id) = @{$ref};
                $data->{$col} = $id;
            } else {
                $data->{$col} = 0;
                $importer->Postpone(
                    for => $ref_uid,
                    uid => $uid,
                    column => $col,
                );
            }
        }
    }

    return 1;
}

sub PostInflate {
}

1;
