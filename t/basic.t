use FindBin '$Bin';
use lib "$Bin/lib", "$Bin/../lib";

use Test::More;
use Test::Deep;

use qbit;

BEGIN {use_ok('TestApplication')}
my $app = new_ok('TestApplication');

sub throws_ok(&$$) {
    my ($code, $exception_type, $exception_text) = @_;

    my $exception;
    try {
        $code->();
    }
    catch {
        $exception = shift;
    };

    if (defined($exception)) {
        isa_ok($exception, $exception_type);
        is($exception->message(), $exception_text, 'Invalid exception message');
    }
}

cmp_deeply(
    [sort map {$_->name} $app->users->get_model_fields()],
    [qw(additional_contacts email forced_dep full_email id name)],
    'Checking available field w/o right'
);

{
    my $tmp_rights = $app->add_tmp_rights('users_view_dep_l2');
    cmp_deeply(
        [sort map {$_->name} $app->users->get_model_fields()],
        [qw(additional_contacts dep_l2 dep_l3 email forced_dep full_email id name)],
        'Checking available field with right'
    );
}

cmp_deeply(
    [sort $app->users->{'__FIELDS__'}->{'forced_dep'}->get_all_depends()],
    [qw(dep_l2 dep_l3 email full_email id name)],
    'Checking expanding depends'
);

cmp_deeply(
    $app->users->add_multi(
        [
            {name => 'Test user 1', email => 'email1@example.com'},
            {name => 'Test user 2', email => 'email2@example.com'},
            {name => 'Test user 3', email => 'email3@example.com'},
            {name => 'Test user 4', email => 'email4@example.com'},
            {name => 'Test user 5', email => 'email5@example.com'},
        ]
    ),
    [1, 2, 3, 4, 5],
    'Checking method add'
);

throws_ok (
    sub {$app->users->add({name => 'Test user', email => 'bad_email@@example.com'})},
    'Exception::Data::FieldsErrors',
    'Invalid field "email"'
);

throws_ok (
    sub {$app->users->add({name => 'T', email => 'bad_email@@example.com'})},
    'Exception::Data::FieldsErrors',
    'Invalid fields "email, name"'
);

cmp_deeply(
    $app->users->get_all(fields => [qw(name full_email forced_dep additional_contacts.phone additional_contacts.fax)]),
    [
        {
            name                        => 'Test user 1',
            full_email                  => 'Test user 1 <email1@example.com>',
            forced_dep                  => '1|1d6a10ece4a1db534b4327ff15056b8e',
            'additional_contacts.phone' => '+0 111-11-11',
            'additional_contacts.fax'   => '+0 211-11-11'
        },
        {
            name                        => 'Test user 2',
            full_email                  => 'Test user 2 <email2@example.com>',
            forced_dep                  => '2|30ffad2357cc19e95b003179fbb33d75',
            'additional_contacts.phone' => '+0 111-11-12',
            'additional_contacts.fax'   => '+0 211-11-12'
        },
        {
            name                        => 'Test user 3',
            full_email                  => 'Test user 3 <email3@example.com>',
            forced_dep                  => '3|6917375fa3cdfb4fbd632a2b07797ec5',
            'additional_contacts.phone' => '+0 111-11-13',
            'additional_contacts.fax'   => '+0 211-11-13'
        },
        {
            name                        => 'Test user 4',
            full_email                  => 'Test user 4 <email4@example.com>',
            forced_dep                  => '4|954fa3a68c032a9add661db975f1ef23',
            'additional_contacts.phone' => '+0 111-11-14',
            'additional_contacts.fax'   => '+0 211-11-14'
        },
        {
            name                        => 'Test user 5',
            full_email                  => 'Test user 5 <email5@example.com>',
            forced_dep                  => '5|ec95dacfea5936f510dd345ac856851f',
            'additional_contacts.phone' => '+0 111-11-15',
            'additional_contacts.fax'   => '+0 211-11-15'
        },
    ],
    'Checking method get_all w/o expressions'
);

cmp_deeply(
    $app->users->get_all(
        fields => {
            id => '',
            t1 => \100500,
            t2 => ['+' => ['id', \10]],
            t3 => {NOT  => ['id']},
            t4 => [name => like => \'2']
        },
        filter => [AND => [[id => '<=' => \3], [name => like => \'user']]]
    ),
    [
        {id => 1, t1 => 100500, t2 => 11, t3 => FALSE, t4 => FALSE},
        {id => 2, t1 => 100500, t2 => 12, t3 => FALSE, t4 => TRUE},
        {id => 3, t1 => 100500, t2 => 13, t3 => FALSE, t4 => FALSE},
    ],
    'Checking expressions and filter'
);

is_deeply($app->users->_pk2filter(1), [id => '=' => \1], 'Checking _pk2filter (scalar)');
is_deeply($app->users->_pk2filter({id => 1, name => 'test'}), [id => '=' => \1], 'Checking _pk2filter (hash)');
is_deeply($app->users->_pk2filter([1]), [id => '=' => \1], 'Checking _pk2filter (array)');

done_testing();
