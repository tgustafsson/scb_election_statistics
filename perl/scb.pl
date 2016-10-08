use List::Util;
use LWP::UserAgent;
use HTTP::Request;
use JSON;

my $ua = LWP::UserAgent->new;
my $url = "http://api.scb.se/OV0104/v1/doris/sv/ssd/START/ME/ME0104/ME0104D/ME0104T4";
my $req = HTTP::Request->new(POST => $url);
my $content = encode_json({query => [{code =>"Region", selection => {filter => "all", values => ["*"]}},
                                     {code => "ContentsCode", selection => {filter => "item", values => ["ME0104B8"]}},
				     {code => "Tid", selection => {filter => "all", values => ["*"]}}],
			   response => {format => "json"}});
$req->content($content);
$req->content_type("application/json");
my $response1 = $ua->get($url);
my $response2 = $ua->request($req);
if ($response1->is_success() && $response2->is_success()) {
    my $meta = decode_json($response1->decoded_content);
    my $data = decode_json(substr($$response2{"_content"}, 3))->{"data"};
    my %map_riktnummer_to_ort;
    @map_riktnummer_to_ort{@{${$meta->{"variables"}}[0]->{"values"}}} = @{${$meta->{"variables"}}[0]->{"valueTexts"}};
    my @year_value_riktnummer = map { {year => @{$_->{"key"}}[1], value => @{$_->{"values"}}[0], riktnummer => @{$_->{"key"}}[0]} } @{$data};
    my %temp = map {$_->{"year"} => 0} @year_value_riktnummer;
    my @years = sort (keys %temp);
    foreach my $year (@years) {
	my @correct_year = grep {$_->{"year"} eq $year} @year_value_riktnummer;
	my @sorted = sort {$a->{"value"} <= $b->{"value"} } @correct_year;
	my @all_largest = grep {$_->{"value"} == $sorted[0]->{"value"}} @sorted;
	my @orter = map {$map_riktnummer_to_ort{$_->{"riktnummer"}}} @all_largest;
	print "$year @orter " . $sorted[0]->{"value"} . "%\n";
    }
}
else
{
    print "Nej!";
}
