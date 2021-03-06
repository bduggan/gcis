use FindBin;
use lib $FindBin::Bin;
use tinit;
use Test::More;
use Test::MBD qw/-autostart/;
use Test::Mojo;

my $t = Test::Mojo->new("Tuba");
$t->app->db->dbh->do(q[delete from publication_type where identifier='dataset']);
$t->app->db->dbh->do(q[insert into publication_type ("table",identifier) values ('dataset','dataset')]);
$t->app->db->dbh->do(q[delete from audit.logged_actions]);

$t->ua->max_redirects(1);
$t->post_ok("/login" => form => { user => "unit_test", password => "anything" })->status_is(200);
$t->ua->max_redirects(1);

my $event_id = $t->ua->on(start => sub { pop->req->headers->header("Accept" => "application/json")});

# Add a role
$t->post_ok("/role_type" => json => {
        identifier => 'data_archive',
        label => "Data Archive"})->status_is(200);

# Add an organization
$t->post_ok(
  "/organization" => json => {
    identifier  => 'baits',
    name        => "Big Archive in the Sky",
  }
)->status_is(200);

$t->post_ok(
  "/organization" => json => {
    identifier  => 'baits_too',
    name        => "Big Archive in the Sky Deux",
  }
)->status_is(200);

# Make a dataset
$t->post_ok("/dataset" => json => { identifier => 'big_dataset', name => 'Big Dataset' })->status_is(200);

$t->post_ok("/dataset/contributors/big_dataset" => json =>
    {organization_identifier => 'baits', role => 'data_archive' })->status_is(200);

$t->get_ok("/dataset/contributors/big_dataset")->json_is("/contributors/0/organization/identifier" => $id);

# Replace baits with baits_too
# What, these are the same person?  Okay merge them.

$t->post_ok("/dataset/contributors/big_dataset" => json =>
    {organization_identifier => 'baits_too', role => 'data_archive', remove_others_with_role => 'data_archive' })->status_is(200);

$t->get_ok("/dataset/big_dataset")->status_is(200)
    ->json_is("/contributors/0/organization/identifier" => "baits_too")
    ->json_is("/contributors/1/organization/identifier" => undef);

$t->delete_ok("/dataset/big_dataset")->status_is(200);
$t->delete_ok("/organization/baits")->status_is(200);
$t->delete_ok("/organization/baits_too")->status_is(200);
$t->delete_ok("/role_type/data_archive")->status_is(200);

done_testing();
