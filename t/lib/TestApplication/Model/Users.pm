package TestApplication::Model::Users;

use qbit;

use base qw(QBit::Application::Model::Data);

use Digest::MD5 qw(md5_hex);

__PACKAGE__->model_accessors(user_contacts => 'TestApplication::Model::UserContacts');

sub _fields_ {
    return (
        id   => {type => 'number', default => TRUE, caption => 'User ID'},
        name => {
            type    => 'text',
            default => TRUE,
            length  => 63,
            caption => d_gettext('Name'),
            check   => sub {throw Exception::Data::FieldError 'Too short name' if length(shift) < 3}
        },
        email => {
            type    => 'text',
            length  => 255,
            caption => d_gettext('EMail'),
            check   => sub {throw Exception::Data::FieldError 'Invalid E-Mail' unless check_email(shift)}
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

my @DATA = ();

sub _add_multi {
    my ($self, $data, %opts) = @_;

    foreach (@$data) {
        $_->{'id'} = @DATA + 1;
        push(@DATA, $_);
    }

    return $data;
}

sub _get_data {
    my ($self, $fields, %opts) = @_;

    return map {+{hash_transform($_, [keys(%$fields)])}}
      grep {exists($opts{'filter'}) && $opts{'filter'}->eval($_) || !exists($opts{'filter'})} @DATA;
}

TRUE;
