#!/bin/bash
#
# Evaluate .travis.yml matrix and generate a script which would run the tests.
# That generated-tests.sh then has to be run as root manually.
# It will run all tests in parallel, probably maxing out the system. It runs in a screen session.

BINDMOUNTDIR=`realpath $PWD/../..`
BUILDER="pbuilder --execute __buildscript.sh"
RUBY_SCRIPT=$(cat <<__END
data = YAML::load(STDIN.read)
exclude = data['matrix']['exclude']
data['rvm'].each{|rvm|
  data['env'].each{|env|
    do_exclude = false
    exclude.each{|x|
      do_exclude = true if x['rvm'] == rvm && x['env'] == env
    }
    unless do_exclude
      session="#{rvm}.#{env.sub(' ','_').sub('=','_')}"
      puts "echo '(env BINDMOUNTDIR=${BINDMOUNTDIR} RVM=#{rvm} #{env} ${BUILDER} && echo '\\\\''OK'\\\\'' || echo '\\\\''FAILED'\\\\'') 2>&1 | tee \"log.\$\$.#{session}\"; read a' > \"run.#{session}\""
      puts "chmod 700 \"run.#{session}\""
      puts "screen -S backlogci -X screen \"./run.#{session}\""
    end
  }
}
__END
)

cat <<_END > generated-tests.sh
#!/bin/bash
screen -dmS backlogci
screen -S backlogci -X screen top
_END
cat ../../.travis.yml |ruby -ryaml -e "$RUBY_SCRIPT" >> generated-tests.sh
echo "screen -RS backlogci -p 1" >> generated-tests.sh
chmod 700 generated-tests.sh

echo "Now run generated-tests.sh as root."
