#!/bin/bash

mandatory_binaries=( "java" "javac" )

for mandatory_binary in "${mandatory_binaries[@]}"
do
  if ! type "$mandatory_binary" > /dev/null; then
    echo "Please install $mandatory_binary"
    exit
  fi
done

if [ "$#" -ne "3" ]; then
  script_name=`basename "$0"`
  cat << EOF
  USAGE
    $script_name GRAMMAR INPUT RULE
  PARAMETERS
    GRAMMAR    the name of the ANTLR grammar
    INPUT      either the name of the file to parse, or the (string)
               source for the parser to process
    RULE       the name of the parser rule to invoke
  EXAMPLE
    $script_name Expr.g4 "(1 + 2) / Pi" parse
EOF
  exit 1
fi

if [ ! -f "$1" ]; then
  echo "no such grammar: $1"
  exit
fi

function get_lib_path
{
  pushd `dirname $0` > /dev/null
  local path=`pwd`/lib
  popd > /dev/null
  echo "$path"
}

function check_antlr_jar
{
  if [ ! -f "$1" ]; then
    echo "No ANTLR JAR found!"
    echo Try: curl -o "$1" "http://www.antlr.org/download/antlr-$antlr_version-complete.jar"
    exit;
    #curl -o "$1" "http://www.antlr.org/download/antlr-$antlr_version-complete.jar"
  fi
}

function write_main_class
{
  cat >"$1" <<EOL
  import org.antlr.v4.runtime.*;
  import org.antlr.v4.runtime.atn.*;
  import java.io.*;
  public class __Antlr4Test__ {
      private static void printPrettyLispTree(String tree) {
          int indentation = 1;
          for (char c : tree.toCharArray()) {
              if (c == '(') {
                  if (indentation > 1) {
                      System.out.println();
                  }
                  for (int i = 0; i < indentation; i++) {
                      System.out.print("  ");
                  }
                  indentation++;
              }
              else if (c == ')') {
                  indentation--;
              }
              System.out.print(c);
          }
          System.out.println();
      }
      public static void main(String[] args) throws IOException {
          String source = "$3";
          ${2}Lexer lexer = new File(source).exists() ?
                  new ${2}Lexer(CharStreams.fromFileName(source)) :
                  new ${2}Lexer(CharStreams.fromString(source));
          CommonTokenStream tokens = new CommonTokenStream(lexer);
          tokens.fill();
          System.out.println("\n[TOKENS]");
          for (Token t : tokens.getTokens()) {
              String symbolicName = ${2}Lexer.VOCABULARY.getSymbolicName(t.getType());
              String literalName = ${2}Lexer.VOCABULARY.getLiteralName(t.getType());
              System.out.printf("  %-20s '%s'\n",
                      symbolicName == null ? literalName : symbolicName,
                      t.getText().replace("\r", "\\r").replace("\n", "\\n").replace("\t", "\\t"));
          }
          System.out.println("\n[PARSE-TREE]");
          ${2}Parser parser = new ${2}Parser(tokens);
          parser.removeErrorListeners();
          //parser.getInterpreter().setPredictionMode(PredictionMode.SLL);
          //parser.setErrorHandler(new BailErrorStrategy());
          parser.setErrorHandler(new DefaultErrorStrategy());
          ParserRuleContext context = parser.${4}();
          String tree = context.toStringTree(parser);
          printPrettyLispTree(tree);
      }
  }
EOL
}

# Declare some variables
grammar_file="$1"
input="$2"
rule_name="$3"
main_class_name="__Antlr4Test__"
main_class_file="$main_class_name.java"
grammar_name=${grammar_file%.*}
antlr_version="4.7.1"
lib_path=$(get_lib_path)
#antlr_jar="/Users/dhowe/.nuget/packages/antlr4.codegenerator/4.6.4/build/../tools/antlr4-csharp-4.6.4-complete.jar"
antlr_jar="lib/antlr-4.7.1-complete.jar"
prefix=$(echo $grammar_file | cut -f 1 -d '.')


# Make sure the ANTLR jar is available
check_antlr_jar "$antlr_jar"

# Generate the lexer and parser classes
java -cp "$antlr_jar" org.antlr.v4.Tool "$grammar_file"

# Generate a main class
write_main_class "$main_class_file" "$grammar_name" "$input" "$rule_name"

# Compile all .java source files and run the main class
javac -cp "$antlr_jar:." *.java
java -cp "$antlr_jar:." "$main_class_name"

# Cleanup
#cat $main_class_name.java
rmfiles="$prefix*.java $prefix*.class $prefix*.interp $prefix*.tokens $main_class_name.java $main_class_name.class"
rm $rmfiles
