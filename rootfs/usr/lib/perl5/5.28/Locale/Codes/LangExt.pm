package Locale::Codes::LangExt;


use strict;
use warnings;
require 5.006;
use Exporter qw(import);

our($VERSION,@EXPORT);
$VERSION   = '3.56';

use if $] >= 5.027007, 'deprecate';
use Locale::Codes;
use Locale::Codes::Constants;

@EXPORT    = qw(
                code2langext
                langext2code
                all_langext_codes
                all_langext_names
                langext_code2code
               );
push(@EXPORT,@Locale::Codes::Constants::CONSTANTS_LANGEXT);

our $obj = new Locale::Codes('langext');
$obj->show_errors(0);

sub show_errors {
   my($val) = @_;
   $obj->show_errors($val);
}

sub code2langext {
   return $obj->code2name(@_);
}

sub langext2code {
   return $obj->name2code(@_);
}

sub langext_code2code {
   return $obj->code2code(@_);
}

sub all_langext_codes {
   return $obj->all_codes(@_);
}

sub all_langext_names {
   return $obj->all_names(@_);
}

sub rename_langext {
   return $obj->rename_code(@_);
}

sub add_langext {
   return $obj->add_code(@_);
}

sub delete_langext {
   return $obj->delete_code(@_);
}

sub add_langext_alias {
   return $obj->add_alias(@_);
}

sub delete_langext_alias {
   return $obj->delete_alias(@_);
}

sub rename_langext_code {
   return $obj->replace_code(@_);
}

sub add_langext_code_alias {
   return $obj->add_code_alias(@_);
}

sub delete_langext_code_alias {
   return $obj->delete_code_alias(@_);
}

1;
