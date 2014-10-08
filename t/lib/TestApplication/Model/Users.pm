package TestApplication::Model::Users;

use qbit;

use base qw(QBit::Application::Model::Data);

use Digest::MD5 qw(md5_hex);

__PACKAGE__->model_accessors(user_contacts => 'TestApplication::Model::UserContacts');

__PACKAGE__->register_rights(
    [
        {
            name        => 'users',
            description => d_gettext('Rights to manage users'),
            rights      => {users_view_all => d_gettext('Right to view all users')}
        }
    ]
);

sub _fields_ {
    return (
        id   => {type => 'number', default => TRUE, caption => 'User ID', readonly => TRUE},
        name => {
            type    => 'text',
            default => TRUE,
            length  => 63,
            caption => d_gettext('Name'),
            check   => sub {
                throw Exception::Data::FieldError 'Too short name' if length(shift) < 3;
                return TRUE;
              }
        },
        email => {
            type    => 'text',
            length  => 255,
            caption => d_gettext('EMail'),
            check   => sub {
                throw Exception::Data::FieldError 'Invalid E-Mail' unless check_email(shift);
                return TRUE;
            },
            editing_rights => ['users_edit_email'],
        },
        full_email => {
            type       => 'code',
            depends_on => [qw(name email)],
            get        => sub {
                my ($model, $rec) = @_;
                return "$rec->{'name'} <$rec->{'email'}>";
              }
        },
        dep_l2 => {
            type         => 'code',
            check_rights => ['users_view_dep_l2'],
            depends_on   => 'full_email',
            get          => sub {
                return "$_[1]->{'full_email'}|l2";
              }
        },
        dep_l3 => {
            type       => 'code',
            depends_on => 'dep_l2',
            get        => sub {
                return "$_[1]->{'dep_l2'}|l3";
              }
        },
        forced_dep => {
            type              => 'code',
            depends_on        => 'id',
            forced_depends_on => 'dep_l3',
            get               => sub {
                return "$_[1]->{'id'}|" . md5_hex($_[1]->{'dep_l2'});
              }
        },
        additional_contacts => {
            type        => 'ext_model',
            from        => 'user_contacts',
            join_fields => [['id'] => ['id']],
        }
    );
}

sub _pk_ {'id'}

sub _default_filter_ {
    my ($self) = @_;

    return $self->check_rights('users_view_all') ? () : [id => '=' => \$self->get_option(cur_user => {})->{'id'}];
}

my @DATA = ();

sub _add_multi {
    my ($self, $data, %opts) = @_;

    foreach (@$data) {
        $_->{'id'} = @DATA + 1;
        push(@DATA, $_);
    }

    return $data;
}

sub _edit {
    my ($self, $new_data, %opts) = @_;

    my @result;

    foreach (@DATA) {
        next if exists($opts{'filter'}) && !$opts{'filter'}->eval($_);
        push_hs($_, $new_data);
        push(@result, $_);
    }

    return \@result;
}

sub _get_data {
    my ($self, $fields, %opts) = @_;

    return map {+{hash_transform($_, [keys(%$fields)])}}
      grep {exists($opts{'filter'}) && $opts{'filter'}->eval($_) || !exists($opts{'filter'})} @DATA;
}

sub _delete {
    my ($self, %opts) = @_;

    my @deleted;
    @DATA = grep {
        exists($opts{'filter'}) && $opts{'filter'}->eval($_) ? do {push(@deleted, $_); ()} : $_
    } @DATA;

    return \@deleted;
}

TRUE;
