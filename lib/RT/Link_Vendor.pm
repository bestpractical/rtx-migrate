package RT::Link;
use strict;
use warnings;

sub FindDependencies {
    my $self = shift;
    my ($walker, $deps) = @_;

    $self->SUPER::FindDependencies($walker, $deps);

    $deps->Add( out => $self->BaseObj )   if $self->BaseObj   and $self->BaseObj->id;
    $deps->Add( out => $self->TargetObj ) if $self->TargetObj and $self->TargetObj->id;
}

sub Serialize {
    my $self = shift;
    my %args = (@_);
    my %store = $self->SUPER::Serialize(@_);

    delete $store{LocalBase}   if $store{Base};
    delete $store{LocalTarget} if $store{Target};
    return %store;
}


sub PreInflate {
    my $class = shift;
    my ($importer, $uid, $data) = @_;

    for my $dir (qw/Base Target/) {
        my $uid_ref = $data->{$dir};
        next unless $uid_ref and ref $uid_ref;

        my $to_uid = ${ $uid_ref };
        my $obj = $importer->LookupObj( $to_uid );
        if ($obj) {
            $data->{$dir} = $obj->URI;
            $data->{"Local$dir"} = $obj->Id if $obj->isa("RT::Ticket");
        } else {
            $data->{$dir} = "";
            $importer->Postpone(
                for => $to_uid,
                uid => $uid,
                uri => $dir,
                column => ($to_uid =~ /RT::Ticket/ ? "Local$dir" : undef),
            );
        }

    }

    return $class->SUPER::PreInflate( $importer, $uid, $data );
}

1;
