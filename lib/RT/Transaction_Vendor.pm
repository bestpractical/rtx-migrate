package RT::Transaction;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->Object );
    $deps->Add( in => $self->Attachments );

    my $type = $self->Type;
    if ($type eq "CustomField") {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->Load( $self->Field );
        $deps->Add( out => $cf );
    } elsif ($type =~ /^(Take|Untake|Force|Steal|Give)$/) {
        for my $field (qw/OldValue NewValue/) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load( $self->$field );
            $deps->Add( out => $user );
        }
    } elsif ($type eq "DelWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $self->OldValue );
        $deps->Add( out => $principal->Object );
    } elsif ($type eq "AddWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $self->NewValue );
        $deps->Add( out => $principal->Object );
    } elsif ($type eq "DeleteLink") {
        if ($self->OldValue) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $self->OldValue );
            $deps->Add( out => $base->Object ) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "AddLink") {
        if ($self->NewValue) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $self->NewValue );
            $deps->Add( out => $base->Object ) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "Set" and $self->Field eq "Queue") {
        for my $field (qw/OldValue NewValue/) {
            my $queue = RT::Queue->new( RT->SystemUser );
            $queue->Load( $self->$field );
            $deps->Add( out => $queue );
        }
    } elsif ($type =~ /^(Add|Open|Resolve)Reminder$/) {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        $ticket->Load( $self->NewValue );
	$deps->Add( out => $ticket );
    }
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    my $type = $store{Type};
    if ($type eq "CustomField") {
        my $cf = RT::CustomField->new( RT->SystemUser );
        $cf->Load( $store{Field} );
        $store{Field} = \($cf->UID);
    } elsif ($type =~ /^(Take|Untake|Force|Steal|Give)$/) {
        for my $field (qw/OldValue NewValue/) {
            my $user = RT::User->new( RT->SystemUser );
            $user->Load( $store{$field} );
            $store{$field} = \($user->UID);
        }
    } elsif ($type eq "DelWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $store{OldValue} );
        $store{OldValue} = \($principal->UID);
    } elsif ($type eq "AddWatcher") {
        my $principal = RT::Principal->new( RT->SystemUser );
        $principal->Load( $store{NewValue} );
        $store{NewValue} = \($principal->UID);
    } elsif ($type eq "DeleteLink") {
        if ($store{OldValue}) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $store{OldValue} );
            $store{OldValue} = \($base->Object->UID) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "AddLink") {
        if ($store{NewValue}) {
            my $base = RT::URI->new( $self->CurrentUser );
            $base->FromURI( $store{NewValue} );
            $store{NewValue} = \($base->Object->UID) if $base->Resolver and $base->Object;
        }
    } elsif ($type eq "Set" and $store{Field} eq "Queue") {
        for my $field (qw/OldValue NewValue/) {
            my $queue = RT::Queue->new( RT->SystemUser );
            $queue->Load( $store{$field} );
            $store{$field} = \($queue->UID);
        }
    } elsif ($type =~ /^(Add|Open|Resolve)Reminder$/) {
        my $ticket = RT::Ticket->new( RT->SystemUser );
        $ticket->Load( $store{NewValue} );
        $store{NewValue} = \($ticket->UID);
    }

    return %store;
}

sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    if ($data->{Object} and ref $data->{Object}) {
        my $on_uid = ${ $data->{Object} };
        return if $importer->ShouldSkipTransaction($on_uid);
    }

    if ($data->{Type} eq "DeleteLink" and ref $data->{OldValue}) {
        my $uid = ${ $data->{OldValue} };
        my $obj = $importer->LookupObj( $uid );
        $data->{OldValue} = $obj->URI;
    } elsif ($data->{Type} eq "AddLink" and ref $data->{NewValue}) {
        my $uid = ${ $data->{NewValue} };
        my $obj = $importer->LookupObj( $uid );
        $data->{NewValue} = $obj->URI;
    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

1;
