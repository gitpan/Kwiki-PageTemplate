package Kwiki::PageTemplate;
use strict;
use warnings;
use YAML;
use List::Util qw(max);
use Kwiki::Plugin '-Base';
use mixin 'Kwiki::Installer';
our $VERSION = '0.01';

field class_id => 'page_template';
field class_title => 'Page Template';
const cgi_class => 'Kwiki::PageTemplate::CGI';

const config_file => 'page_template.yaml';

field fields => {};

sub register {
    my $reg = shift;
    $reg->add(action => 'new_from_page_template');
    $reg->add(wafl   => 'field' => 'Kwiki::PageTemplate::FieldPhrase');
    $reg->add(wafl   => 'page_template' => 'Kwiki::PageTemplate::TemplateBlock');
    $reg->add(wafl   => 'page_template_fields' => 'Kwiki::PageTemplate::FieldBlock');
    $reg->add(wafl   => 'page_template_content' => 'Kwiki::PageTemplate::ContentBlock');
}

sub new_from_page_template {
    my $fields = $self->fields_of($self->cgi->template_page);
    $self->fields($fields);
    my %raw = $self->cgi->vars;
    my %values;
    for (keys %$fields) {
	my $field_name = "field_".$_;
	$values{$_} = $raw{$field_name};
    }
    my $page = $self->get_new_page($self->cgi->page_id_prefix);
    my $content  =
	".page_template_content\n"
	. YAML::Dump({template => $self->cgi->template_page , values => \%values})
	. "\n.page_template_content\n";
    $page->content($content);
    $page->store;
    $self->redirect($page->id);
}

sub fields_of {
    my $page_id = shift;
    my $content = $self->hub->pages->new_page($page_id)->content;
    my ($block) = $content =~ /.page_template_fields\n(.+?).page_template_fields/s;
    return YAML::Load($block);
}

sub get_new_page {
    my $prefix = shift;
    my $num = 1 + max(map {s/^.*(\d+)$/$1/; $_} grep { /^$prefix/ }
			  $self->hub->pages->all_ids_newest_first);
    $self->pages->new_page("${prefix}${num}");
}

package Kwiki::PageTemplate::FieldBlock;
use base 'Spoon::Formatter::WaflBlock';

sub to_html {
    $self->hub->page_template->fields(YAML::Load($self->block_text));
    "";
}

package Kwiki::PageTemplate::ContentBlock;
use base 'Spoon::Formatter::WaflBlock';

sub to_html {
    my $p = YAML::Load($self->block_text);
    my $tp = $self->hub->pages->new_page($p->{template});
    my $content = $tp->content;
    $content =~ s/.*\.page_template\s+(.*)\s+\.page_template.*/$1/s;
    for(keys %{$p->{values}}) {
	$content =~ s/{field:\s*$_\s*}/$p->{values}->{$_}/;
    }

    $self->hub->page_template->template_process(
	'page_template_content.html',
	content => $self->hub->formatter->text_to_html($content)
       );
}

package Kwiki::PageTemplate::TemplateBlock;
use base 'Spoon::Formatter::WaflBlock';

sub to_html {
    my $plugin = $self->hub->page_template;
    my $prefix = $plugin->fields->{page_id_prefix}
        || $self->hub->config->page_template_page_id_prefix;
    $plugin->template_process(
	'page_template_form.html',
	template_page => $plugin->pages->current->id,
	content => $self->hub->formatter->text_to_html($self->block_text) ,
          page_template_page_id_prefix => $prefix
       );
}


package Kwiki::PageTemplate::CGI;
use base 'Kwiki::CGI';

cgi 'template_page';
cgi 'page_id';
cgi 'page_id_prefix';
cgi 'button';

package Kwiki::PageTemplate::FieldPhrase;
use base 'Spoon::Formatter::WaflPhrase';

sub to_html {
    my $fields = $self->hub->page_template->fields;
    my $name = $self->arguments;
    my $type = $fields->{$name};

    $name = "field_$name";
    push @{$Kwiki::PageTemplate::CGI::all_params_by_class->{'Kwiki::PageTemplate::CGI'}}, $name;
    if($type eq 'textarea') {
	return qq{<textarea name="$name" style="width: 85%; height: 24em;vertical-align:top;"></textarea>};
    } elsif (ref($type) eq 'ARRAY') {
	my $ret = qq{<select name="$name">};
	for(@$type) {
	    $ret .= qq{<option value="$_">$_</option>}
	}
	$ret .= "</select>";
	return $ret;
    }
    return qq{<input type="text" name="$name"/>};
}

package Kwiki::PageTemplate::Meta;
use base 'Spoon::Formattor::WaflBlock';

sub to_html {}

package Kwiki::PageTemplate;

1;

=head1 NAME

  Kwiki::PageTemplate - pre-fill kwiki page with this template

=head1 SYNOPSIS

Paste this into your SandBox and visit the SandBox.

  .page_template_fields
  page_id_prefix: Resume
  name: text
  gender:
      - Woman
      - Woman-in-man
  bio: textarea
  .page_template_fields

  .page_template
  = Resume form

  My name: {field:name}

  Email: {field:name}

  Biograph:
  {field:bio}
  .page_template

  Fill the above form and you will probabally get the job.

=head1 DESCRIPTION

This purpose of this plugin is to let your Kwiki User edit
pages even more easily. They only have to type some characters
into a given form, submit it, and done. Not even Kwiki formatter
syntax knowledged required.

The basic idea is from mac.com hompage editing, they provide a nearly
WYSIWYG web interface to edit your homepage, because the have many
pr-defined HTML templates, which are a big form, after you submit that
form, what you just inputed replace the original input fields, becomes
the content of the generated page.

The "page_template_fields" wafl block is a YAML block where you can
define your form variables, and their input types, if the type is a
array, it'll become a pull-down select menu. After user submit the
form, this plugin will generate a page prefixed with the value
"page_template_page_id_prefix", default to "PageTemplateGenerated" in
your config/page_template.yaml, but you may specify "page_id_prefix"
in the page_template_fields wafl block to override this. The example
given in SYNOPSIS demostrate this feature, let the form generate a
page named like "Resume3", the number afterwards are increased
automatically each time somebody submit the form.

This plugin is still in it's early development and currently,
re-editing the generated page is not implemented, and something may
break in the future. So use it at your on risk.

=head1 COPYRIGHT

Copyright 2004 by Kang-min Liu <gugod@gugod.org>.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

See <http://www.perl.com/perl/misc/Artistic.html>

=cut

__DATA__
__config/page_template.yaml__
page_template_save_button_text: SAVE
page_template_page_id_prefix: PageTemplateGenerated
__template/tt2/page_template_form.html__
<!-- BEGIN page_template_form.html -->
<form method="POST">
<input type="hidden" name="action" value="new_from_page_template" />
<input type="hidden" name="page_id_prefix" value="[% page_template_page_id_prefix %]" />
<input type="hidden" name="template_page" value="[% template_page %]" />
<input type="submit" name="button" value="[% page_template_save_button_text %]" />
[% content %]
</form>
<!-- END page_template_form.html -->
__template/tt2/page_template_content.html__
<!-- BEGIN page_template_content.html -->
[% content %]
<!-- END page_template_content.html -->
