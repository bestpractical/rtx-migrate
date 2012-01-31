package RT::Class;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    my $articles = RT::Articles->new( $self->CurrentUser );
    $articles->Limit( FIELD => "Class", VALUE => $self->Id );
    $deps->Add( in => $articles );

    my $topics = RT::Topics->new( $self->CurrentUser );
    $topics->LimitToObject( $self );
    $deps->Add( in => $topics );

    my $objectclasses = RT::ObjectClasses->new( $self->CurrentUser );
    $objectclasses->LimitToClass( $self->Id );
    $deps->Add( in => $objectclasses );

    # Custom Fields on things _in_ this class (CFs on the class itself
    # have already been dealt with)
    my $ocfs = RT::ObjectCustomFields->new( $self->CurrentUser );
    $ocfs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => $self->id,
                  ENTRYAGGREGATOR => 'OR' );
    $ocfs->Limit( FIELD           => 'ObjectId',
                  OPERATOR        => '=',
                  VALUE           => 0,
                  ENTRYAGGREGATOR => 'OR' );
    my $cfs = $ocfs->Join(
        ALIAS1 => 'main',
        FIELD1 => 'CustomField',
        TABLE2 => 'CustomFields',
        FIELD2 => 'id',
    );
    $ocfs->Limit( ALIAS    => $cfs,
                  FIELD    => 'LookupType',
                  OPERATOR => 'STARTSWITH',
                  VALUE    => 'RT::Class-' );
    $deps->Add( in => $ocfs );
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    $class->SUPER::PreInflate( $importer, $uid, $data );

    return if $importer->MergeBy( "Name", $class, $uid, $data );

    return 1;
}

1;
