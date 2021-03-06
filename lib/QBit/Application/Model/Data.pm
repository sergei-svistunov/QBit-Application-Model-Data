package Exception::Data::FieldsErrors;

use qbit::GetText;

use base qw(Exception::BadArguments);

sub as_string {
    my ($self) = @_;

    return
        $self->SUPER::as_string() . '    '
      . ngettext('Field error', 'Fields errors', scalar(keys(%{$self->{'error_fields'}})))
      . ":\n        "
      . join("\n        ", map {"$_: " . $self->{'error_fields'}{$_}->message()} sort keys(%{$self->{'error_fields'}}))
      . "\n";
}

sub error_fields {
    return {%{$_[0]->{'error_fields'}}};
}

package QBit::Application::Model::Data;

use qbit;

use base qw(QBit::Application::Model);

use QBit::Application::Model::Data::_::Field;
use QBit::Application::Model::Data::_::Expression;

__PACKAGE__->abstract_methods(qw(_add_multi _get_data _edit _delete));

my $INVALID_FIELD_NAME_CHARS_RE = qr/[^a-zA-Z0-9_]/;

sub _default_filter_ {return ()}

sub init {
    my ($self) = @_;

    $self->SUPER::init();

    $self->{'__FIELDS__'}       = {};
    $self->{'__FIELDS_ORDER__'} = [];

    my @fields = $self->_fields_();

    while (@fields) {
        my ($name, $opts) = splice(@fields, 0, 2);
        throw Exception::BadArguments gettext('Invalid name "%s" (%s)', $name, ref($self))
          if $name =~ /$INVALID_FIELD_NAME_CHARS_RE/;

        push(@{$self->{'__FIELDS_ORDER__'}}, $name);

        my $field_class = $opts->{'type'};
        $field_class = 'Self' unless defined($field_class);
        $field_class = $self->_get_fields_namespace() . "::$field_class";

        require_class($field_class);
        $self->{'__FIELDS__'}{$name} = $field_class->new(%$opts, model => $self, name => $name);
    }

    # ToDo: Check field depends

    $self->{'__PK__'} = $self->can('_pk_') ? [$self->_pk_()] : [];
    # ToDo: Check PK

    $self->{'__FIELDS_TREE_LEVEL__'} = {};
    $self->{'__FIELDS_TREE_LEVEL__'}{$_} = $self->_fields_tree_level($_, 0) foreach keys(%{$self->{'__FIELDS__'}});
}
sub get_pk {$_[0]->{'__PK__'}}

sub get_model_fields {
    return grep {$_->is_available} values($_[0]->{'__FIELDS__'});
}

sub get_default_model_fields {
    return map {$_->name} grep {$_->is_default()} $_[0]->get_model_fields();
}

sub get_editable_model_fields {
    return map {$_->name} grep {$_->is_editable()} $_[0]->get_model_fields();
}

sub filter {
    my ($self, $expression) = @_;

    return $self->_get_expression($expression);
}

sub process_data {
    my ($self, $data, $need_fields) = @_;

    # Nothing to do
    return FALSE unless @$data && %$need_fields;

    my @fields_order =
      sort {$self->{'__FIELDS_TREE_LEVEL__'}{$a} <=> $self->{'__FIELDS_TREE_LEVEL__'}{$b}} keys(%$need_fields);

    # Process fields
    $self->{'__FIELDS__'}{$_}->process($data, $need_fields->{$_}) foreach @fields_order;

    return TRUE;
}

sub get_rec_pk {
    my ($self, $rec) = @_;

    my $pk = $self->get_pk();

    if (@$pk == 0) {
        return undef;
    } elsif (@$pk == 1) {
        return $rec->{$pk->[0]};
    } else {
        return {map {$_ => $rec->{$_}} @$pk};
    }
}

sub add_multi {
    my ($self, $data, %opts) = @_;

    my @add_data;

    foreach my $rec (@$data) {
        my %add_data;
        my %error_fields;
        foreach my $field_name (keys(%{$self->{'__FIELDS__'}})) {
            next unless $self->{'__FIELDS__'}{$field_name}->isa('QBit::Application::Model::Data::_::Field::Self');
            try {
                $self->{'__FIELDS__'}{$field_name}->check($rec->{$field_name});
                $add_data{$field_name} = $rec->{$field_name};
            }
            catch Exception::Data::FieldError with {
                $error_fields{$field_name} = $_[0];
            };
        }

        throw Exception::Data::FieldsErrors ngettext(
            'Invalid field "%s"',
            'Invalid fields "%s"',
            scalar(keys(%error_fields)),
            join(', ', sort keys(%error_fields))
          ),
          error_fields => \%error_fields
          if %error_fields;
        push(@add_data, \%add_data);
    }

    return [map {$self->get_rec_pk($_)} @{$self->_add_multi(\@add_data, %opts)}];
}

sub add {
    my ($self, $data, %opts) = @_;

    return $self->add_multi([$data], %opts)->[0];
}

sub edit {
    my ($self, $pk_or_filter, $new_data, %opts) = @_;

    my %editable_model_fields = map {$_ => TRUE} $self->get_editable_model_fields();

    my %error_fields;
    my %data;
    foreach my $field_name (keys(%$new_data)) {
        next unless exists($editable_model_fields{$field_name});
        try {
            $self->{'__FIELDS__'}{$field_name}->check($new_data->{$field_name});
            $data{$field_name} = $new_data->{$field_name};
        }
        catch Exception::Data::FieldError with {
            $error_fields{$field_name} = $_[0];
        };
    }

    throw Exception::Data::FieldsErrors ngettext(
        'Invalid field "%s"',
        'Invalid fields "%s"',
        scalar(keys(%error_fields)),
        join(', ', sort keys(%error_fields))
      ),
      error_fields => \%error_fields
      if %error_fields;

    $pk_or_filter = $self->_pk2filter($pk_or_filter) unless blessed($pk_or_filter);
    my @filter = $self->_with_default_filter($pk_or_filter);

    return $self->_edit(\%data, %opts, (@filter ? (filter => $self->_get_expression($filter[0])) : ()));
}

sub delete {
    my ($self, $pk_or_filter, %opts) = @_;

    $pk_or_filter = $self->_pk2filter($pk_or_filter) unless blessed($pk_or_filter);
    my @filter = $self->_with_default_filter($pk_or_filter);

    return [map {$self->get_rec_pk($_)}
          @{$self->_delete(%opts, (@filter ? (filter => $self->_get_expression($filter[0])) : ()))}];
}

sub get_all {
    my ($self, %opts) = @_;

    $opts{'fields'} = [$self->get_default_model_fields()] unless defined($opts{'fields'});
    $opts{'fields'} = {map {$_ => ''} @{$opts{'fields'}}} if ref($opts{'fields'}) eq 'ARRAY';

    my %available_model_fields = map {$_->name => TRUE} $self->get_model_fields();

    my %res_fields;
    my %need_fields;
    foreach my $name (keys(%{$opts{'fields'}})) {
        $res_fields{$name} = $self->_get_expression($opts{'fields'}{$name} || $name);

        my @expression_fields = map {$self->_split_field($_)} $res_fields{$name}->get_fields();
        my @invalid_fields = grep {!exists($available_model_fields{$_})} map {$_->{'name'}} @expression_fields;
        throw Exception::BadArguments ngettext(
            'Unknown field "%s" in expression "%s"',
            'Unknown fields "%s" in expression "%s"',
            scalar(@invalid_fields),
            join(', ', @invalid_fields),
            Dumper($res_fields{$name}->expression)
        ) if @invalid_fields;

        foreach (@expression_fields) {
            $need_fields{$_->{'name'}} ||= {};
            if (defined($_->{'options'})) {
                $need_fields{$_->{'name'}}->{'options'} ||= [];
                push(@{$need_fields{$_->{'name'}}->{'options'}}, $_->{'options'});
            }
        }
    }

    # Add all fields from depends
    foreach my $field (keys(%need_fields)) {
        $need_fields{$_} = {} foreach $self->{'__FIELDS__'}{$field}->get_all_depends();
    }

    my %self_fields;
    my %gen_fields;
    foreach (keys(%need_fields)) {
        if ($self->{'__FIELDS__'}{$_}->isa('QBit::Application::Model::Data::_::Field::Self')) {
            $self_fields{$_} = {};
        } elsif ($self->{'__FIELDS__'}{$_}->isa('QBit::Application::Model::Data::_::Field::Generate')) {
            $gen_fields{$_} = $need_fields{$_};
        } else {
            throw Exception::BadArguments gettext('Invalid field "%s" type "%s" (%s)', $_,
                ref($self->{'__FIELDS__'}{$_}), ref($self));
        }
    }

    my @filter = $self->_with_default_filter(defined($opts{'filter'}) ? $opts{'filter'} : ());
    my @data = $self->_get_data(\%self_fields, %opts, (@filter ? (filter => $self->_get_expression($filter[0])) : ()));

    $self->process_data(\@data, \%gen_fields);

    my @res;
    foreach my $rec (@data) {
        push(@res, {map {$_ => $res_fields{$_}->eval($rec)} keys(%res_fields)});
    }

    return \@res;
}

sub get {
    my ($self, $pk, %opts) = @_;

    return $self->get_all(%opts, filter => $self->_pk2filter($pk))->[0];
}

sub _get_fields_namespace {'QBit::Application::Model::Data::_::Field'}

sub _get_expression {
    my ($self, $expression) = @_;

    return $expression if blessed($expression) && $expression->isa('QBit::Application::Model::Data::_::Expression');

    return QBit::Application::Model::Data::_::Expression->new(model => $self, expression => $expression);
}

sub _fields_tree_level {
    my ($self, $field_name, $level) = @_;

    return $self->{'__FIELDS_TREE_LEVEL__'}{$field_name} + $level
      if exists($self->{'__FIELDS_TREE_LEVEL__'}{$field_name});

    my @depends_on_fields = $self->{'__FIELDS__'}{$field_name}->get_depends();

    return @depends_on_fields
      ? array_max(map {$self->_fields_tree_level($_, $level + 1)} @depends_on_fields)
      : $level;
}

sub _split_field {
    my ($self, $field) = @_;

    my ($name, $options) = $field =~ /^(.+?)($INVALID_FIELD_NAME_CHARS_RE.+)?$/;

    return {orig_name => $field, name => $name, options => $options};
}

sub _eval_expression {
    my ($self, $operator, @operands) = @_;

    my $res = shift(@operands);
    $operator = uc($operator);

    foreach (@operands) {
        if ($operator eq '+') {
            $res += $_ || 0;
        } elsif ($operator eq '-') {
            $res -= $_ || 0;
        } elsif ($operator eq '*') {
            $res *= $_ || 0;
        } elsif ($operator eq '/') {
            return undef if !defined($_) || $_ == 0;
            $res /= $_;
        } elsif ($operator eq 'AND') {
            $res &&= $_;
        } elsif ($operator eq 'OR') {
            $res ||= $_;
        } else {
            throw Exception::BadArguments gettext('Invalid operator "%s"', $operator);
        }
    }

    return $res;
}

sub _call_function {
    my ($self, $function, @params) = @_;

    $function = uc($function);
    if ($function eq 'NOT') {
        return !$params[0];
    } else {
        throw Exception::BadArguments gettext('Unknown function "%s"', $function);
    }
}

sub _eval_field_operator {
    my ($self, $field_name, $field_value, $operator, $value) = @_;

    throw Exception::BadArguments gettext('Unknown field "%s"', $field_name)
      unless exists($self->{'__FIELDS__'}{$field_name});

    return $self->{'__FIELDS__'}{$field_name}->eval_operator($field_value, $operator, $value);
}

sub _with_default_filter {
    my ($self, @filter) = @_;

    my @def_filter = $self->_default_filter_();

    if (@filter && @def_filter) {
        return ([AND => [$def_filter[0], $filter[0]]]);
    } elsif (@filter) {
        return ($filter[0]);
    } elsif (@def_filter) {
        return ($def_filter[0]);
    } else {
        return ();
    }
}

sub _pk2filter {
    my ($self, $pk_data) = @_;

    my $pk = $self->get_pk();
    my $expression;

    if (ref($pk_data) eq '' && @$pk == 1) {    # For simple pk's can use scalars
        $expression = [$pk->[0] => '=' => \$pk_data];
    } elsif (
        ref($pk_data) eq 'HASH'
        && !grep {                             # Are defined all primary keys?
            !defined($pk_data->{$_})
        } @$pk
      )
    {
        $expression =
          @$pk > 1 ? [AND => [map {[$_ => '=' => \$pk_data->{$_}]} @$pk]] : [$pk->[0] => '=' => \$pk_data->{$pk->[0]}];
    } elsif (ref($pk_data) eq 'ARRAY' && @$pk_data == @$pk) {
        $expression =
          @$pk > 1
          ? [AND => [map {[$pk->[$_] => '=' => \$pk_data->[$_]]} 0 .. @$pk - 1]]
          : [$pk->[0] => '=' => \$pk_data->[0]];
    } else {
        throw Exception::BadArguments gettext('Invalid PK data. Model "%s", data: %s', ref($self), Dumper($pk_data));
    }

    return $self->filter($expression)->{'expression'};
}

TRUE;
