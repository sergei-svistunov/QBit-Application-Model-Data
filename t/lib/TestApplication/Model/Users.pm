package TestApplication::Model::Users;

use qbit;

use base qw(QBit::Application::Model::Data);

use Digest::MD5 qw(md5_hex);

__PACKAGE__->model_accessors(user_contacts => 'TestApplication::Model::UserContacts');

sub _fields_ {
    return (
        id    => {type => 'number', default => TRUE, caption => 'User ID'},
        name  => {type => 'text',   default => TRUE, length  => 63, caption => d_gettext('Name')},
        email => {type => 'text',   length  => 255,  caption => d_gettext('EMail')},
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

my @DATA = (
    {id => 1, name => 'Test user 1', email => 'email1@example.com'},
    {id => 2, name => 'Test user 2', email => 'email2@example.com'},
    {id => 3, name => 'Test user 3', email => 'email3@example.com'},
    {id => 4, name => 'Test user 4', email => 'email4@example.com'},
    {id => 5, name => 'Test user 5', email => 'email5@example.com'},
);

sub _get_data {
    my ($self, $fields, %opts) = @_;

    return map {+{hash_transform($_, [keys(%$fields)])}}
      grep {exists($opts{'filter'}) && $opts{'filter'}->eval($_) || !exists($opts{'filter'})} @DATA;
}

TRUE;
