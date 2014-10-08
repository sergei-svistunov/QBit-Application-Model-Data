package Exception::Data::FieldError;

use base qw(Exception);

package QBit::Application::Model::Data::_::Field;

use qbit;

use base qw(QBit::Class);

__PACKAGE__->mk_ro_accessors(qw(model name));

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    weaken($self->{'model'});

    $self->{'depends_on'} = [$self->{'depends_on'}]
      if defined($self->{'depends_on'}) && ref($self->{'depends_on'}) ne 'ARRAY';

    $self->{'forced_depends_on'} = [$self->{'forced_depends_on'}]
      if defined($self->{'forced_depends_on'}) && ref($self->{'forced_depends_on'}) ne 'ARRAY';
}

sub get_depends {
    my ($self) = @_;

    return (@{$self->{'depends_on'} || []}, @{$self->{'forced_depends_on'} || []});
}

sub get_all_depends {
    my ($self) = @_;

    return @{
        array_uniq(
            $self->get_depends(), map {$self->model->{'__FIELDS__'}->{$_}->get_all_depends()} $self->get_depends()
        ),
      };
}

sub is_available {
    my ($self) = @_;

    return FALSE if defined($self->{'check_rights'}) && !$self->model->app->check_rights(@{$self->{'check_rights'}});

    foreach (@{$self->{'depends_on'} || []}) {
        return FALSE unless $self->model->{'__FIELDS__'}->{$_}->is_available();
    }

    return TRUE;
}

sub is_default {
    my ($self) = @_;

    return !!$self->{'default'};
}

sub is_editable {
    my ($self) = @_;

    return FALSE unless $self->is_available();

    return FALSE if $self->{'readonly'};

    return FALSE
      if defined($self->{'editing_rights'})
          && !$self->model->app->check_rights(@{$self->{'editing_rights'}});

    return TRUE;
}

sub check {
    my ($self, $data) = @_;

    throw Exception::Data::FieldError gettext('Unknown error')
      if defined($self->{'check'}) && !$self->{'check'}->($data);

    return TRUE;
}

sub eval_operator {
    my ($self, $field_value, $operator, $value) = @_;

    if ($operator eq '<' && !ref($value)) {
        return ($field_value || 0) < ($value || 0);
    } elsif ($operator eq '<=' && !ref($value)) {
        return ($field_value || 0) <= ($value || 0);
    } elsif ($operator eq '>' && !ref($value)) {
        return ($field_value || 0) > ($value || 0);
    } elsif ($operator eq '>=' && !ref($value)) {
        return ($field_value || 0) >= ($value || 0);
    } elsif ($operator eq '=' && !ref($value)) {
        return $field_value == $value;
    } elsif ($operator eq '=' && ref($value) eq 'ARRAY') {
        return in_array($field_value, $value);
    } elsif ($operator eq '!=' && !ref($value)) {
        return $field_value != $value;
    } elsif ($operator eq 'lt' && !ref($value)) {
        return ($field_value || '') lt($value || '');
    } elsif ($operator eq 'le' && !ref($value)) {
        return ($field_value || '') le($value || '');
    } elsif ($operator eq 'gt' && !ref($value)) {
        return ($field_value || '') gt($value || '');
    } elsif ($operator eq 'ge' && !ref($value)) {
        return ($field_value || '') ge($value || '');
    } elsif ($operator eq 'like' && !ref($value)) {
        return !!(($field_value || '') =~ /\Q$value\E/i);
    } elsif ($operator eq 'eq' && !ref($value)) {
        return $field_value eq $value;
    } elsif ($operator eq 'ne' && !ref($value)) {
        return $field_value ne $value;
    } else {
        throw Exception::BadArguments gettext('Unknow operator "%s" or argument "%s"', $operator, Dumper($value));
    }
}

TRUE;
