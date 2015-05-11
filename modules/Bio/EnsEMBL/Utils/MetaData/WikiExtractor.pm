=head1 LICENSE

Copyright [2009-2014] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Utils::MetaData::WikiExtractor;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Data::Dumper;
use MediaWiki::API;
use MediaWiki::Parser;
use Text::MediawikiFormat qw(wikiformat);

sub new {
  my $caller = shift;
  my $class  = ref($caller) || $caller;
  my $self   = bless({}, $class);
  $self->{logger} = get_logger();
  $self->{mediawiki} = MediaWiki::API->new();  
  $self->{mediawiki}->{config}->{api_url} = 'http://en.wikipedia.org/w/api.php';
  $self->{parser} = MediaWiki::Parser->new();
  return $self;
}

my $img_root = "";

sub extract_wiki_data {
    my ($self,$dba) = @_;   
    my $meta = $dba->get_MetaContainer();
    my $data = {name=>$meta->get_production_name(),display_name=>$meta->get_display_name()};
    $self->{logger}->info("Retrieving information for ".$data->{name});
    my $wiki_url = $meta->single_value_by_key('species.wikipedia_url');
    if(defined $wiki_url) {
        $data->{wiki_url} = $wiki_url;
        (my $page = $wiki_url) =~ s/.+\/(.+)/$1/;
        $self->{logger}->debug("Processing page ".$page);
        my $page_obj = $self->{mediawiki}->get_page( { title => $page } );
        my $pt = $self->{parser}->from_string( $page_obj->{'*'});

        my $wikitext = '';
        for my $elem (@{$pt->elements()}) {
            if(ref($elem) eq 'MediaWiki::Template') {
                if($elem->{title} eq 'Taxobox') {
                    my $img = $elem->field("image");
                    if(defined $img) {
                        my $img_name = $img->[0];
                        $img_name =~ s/^\s*(.+)\s*$/$1/g;
			my $info = $self->{mediawiki}->api({
			    action=>"query",
			    prop=>"imageinfo",
			    format=>"json",
                            titles=>"File:$img_name",
                            iiurlwidth=>512,
                            iiprop=>"url"});
			my $image_url = $info->{query}{pages}{-1}{imageinfo}[0]{thumburl};
			my $image_credit_url = $info->{query}{pages}{-1}{imageinfo}[0]{descriptionurl};
if(defined $image_url) {
$data->{image_url} = $image_url;
}
if(defined $image_credit_url) {
$data->{image_credit_url} = $image_credit_url;
}
                    }
                }
            } else {
                $wikitext .= $elem;
            } 
        }
        $wikitext =~ s/(.*?)==.*/$1/s;
        # now strip out markup 
	my $html = wikiformat ($wikitext);
	$html =~ s/&gt;/>/g;
	$html =~ s/&lt;/</g;
	$html =~ s/<\/?ref[^>]*>//g;
	$html =~ s/<\/?a[^>]*>//g;
	$data->{description} = $html;
    }
    return $data;
}

1;

__END__

=pod
=head1 NAME

Bio::EnsEMBL::Utils::MetaData::WikiExtractor

=head1 SYNOPSIS

=head1 DESCRIPTION

Class for extracting relevant data from Wikipedia

=head1 SUBROUTINES/METHODS

=head2 new
Description:	Return a new instance of WikiExtractor
Return:			Bio::EnsEMBL::Utils::MetaData::WikiExtractor

=head2 extract_wiki_data
Description:	For a given core DBA, extract basic description and image from wikipedia if available
Argument:		Core DBAdaptor
Return:			Hash ref (name, description, image_url)

=head1 AUTHOR

dstaines

=head1 MAINTAINER

$Author$

=head1 VERSION

$Revision$

=cut
