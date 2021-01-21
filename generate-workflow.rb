# This generates a workflow that runs jobs on the runner OS
# instead of docker.
# 
# USAGE
#
# ruby generate-workflow.rb > .github/workflows/test.yml 
#

require 'yaml'
require 'json'

FILENAME = 'test.yml'
OS = 'ubuntu-latest'
RUBY_VERSIONS = {
    # '2.7' => {}, 
    'truffleruby-head'  => { 
        :test_env => {
            'PARALLEL_WORKERS' => '1',
            'MT_CPU' => '1',
        },
    },
}

def normalize_key(string)
    # Names must start with a letter or '_' and contain only alphanumeric characters, '-', or '_'
   string.gsub(/[^0-9a-z ]/i, '-').gsub(' ', '_')
 end

def bundle_jobs
    RUBY_VERSIONS.inject({}) do |jobs, (ruby_version, config)|
      job = {
          'name' => bundle_job_name(ruby_version),
          'runs-on' => OS,
          'steps' => [
            uses('actions/checkout@master'),
            setup_ruby(ruby_version),
            run('bundle install'),
          ],
        #   'env' => {
        #     'REDIS_DRIVER' => 'ruby',
        #   },
      }
      jobs[normalize_key(bundle_job_name(ruby_version))] = job
      jobs
    end
end

def setup_ruby(version)
    {
     'uses' => 'ruby/setup-ruby@v1', 
     'with' => {'ruby-version' => version, 'bundler-cache' => true},
    }
end

def bundle_job_name(ruby_version)
  "Bundle Install (#{ruby_version} / #{OS})"
end

def generate_jobs
    bundle_jobs().merge(test_jobs())
end

def install(*packages)
    { 'run' => "sudo apt-get install -y --no-install-recommends #{packages.join(' ')}" }
end

def run_in_dir(command, dir)
    {'run' => command, 'working-directory' => dir}
end

def run(command)
    {'run' => command}
end

def setup_mysql
    run("mysql --host 127.0.0.1 --port 3306 -uroot -ppassword -e \"create user rails@'%';grant all privileges on activerecord_unittest.* to rails@'%';grant all privileges on activerecord_unittest2.* to rails@'%';grant all privileges on inexistent_activerecord_unittest.* to rails@'%';create database activerecord_unittest default character set utf8mb4;create database activerecord_unittest2 default character set utf8mb4;
        \"")
end

TESTS = {
    'activesupport' => {
        :dir => 'activesupport',
        :command => 'rake test', 
        :services => [:memcached, :redis],
    },
    'activesupport isolated' => {
        :dir => 'activesupport',
        :command => 'rake test:isolated', 
        :services => [:memcached, :redis],
    },
    'actioncable' => {
        :dir => 'actioncable',
        :command => 'rake test', 
        :services => [:redis],
    },
    'actioncable integration' => {
        :dir => 'actioncable',
        :before_command => [
            run('sudo apt-get update'),
            run('sudo apt remove cmdtest'),
            run('sudo apt remove yarn'),
            install('nodejs-dev', 'node-gyp', 'libssl1.0-dev', 'ffmpeg'),
            install('npm'),
            run('npm install -g yarn'),
            run('yarn -v'),
            run('yarn install'),
            run_in_dir('yarn install', 'actionview'),
        ],
        :command => 'rake test:integration', 
    },
    'actionmailbox' => {
        :dir => 'actionmailbox',
        :command => 'rake test', 
    },
    'actionmailer' => {
        :dir => 'actionmailer',
        :command => 'rake test', 
    },
    'actionmailer isolated' => {
        :dir => 'actionmailer',
        :command => 'rake test:isolated', 
    },
    'actionpack' => {
        :dir => 'actionpack',
        :services => [:memcached],
        :command => 'rake test',  
    },
    'actionpack isolated' => {
        :dir => 'actionpack',
        :services => [:memcached],
        :command => 'rake test:isolated',       
    },
    'actiontext' => {
        :dir => 'actiontext',
        :command => 'rake test',  
    },
    'actionview' => {
        :dir => 'actionview',
        :command => 'rake test',  
    },
    'actionview ujs' => {
        :dir => 'actionview',
        :before_command => [
            run('sudo apt-get update'),
            run('sudo apt remove cmdtest'),
            run('sudo apt remove yarn'),
            install('nodejs-dev', 'node-gyp', 'libssl1.0-dev', 'ffmpeg'),
            install('npm'),
            run('npm install -g yarn'),
            run('yarn -v'),
            run('yarn install'),
            run_in_dir('yarn install', 'actionview'),
        ],
        :command => 'rake test:ujs',  
    },
    'actionview isolated' => {
        :dir => 'actionview',
        :command => 'rake test:isolated',  
    },
    'activejob' => {
        :dir => 'activejob',
        :command => 'rake test',  
    },
    'activejob integration' => {
        :dir => 'activejob',
        :before_command => [
            run('sudo apt-get update'),
            install('postgresql-client')
        ],
        :env => {
            'QUE_DATABASE_URL' => 'postgres://postgres:postgres@postgres/active_jobs_que_int_test',
            'QC_DATABASE_URL' => 'postgres://postgres:postgres@postgres/active_jobs_qc_int_test'
        },
        :command => 'rake test:integration', 
        :services => [:redis, :beanstalkd, :postgres],
    },
    'activejob isolated' => {
        :dir => 'activejob',
        # :before_command => [
        #     run('sudo apt-get update'),
        #     install('postgresql-client')
        # ],
        :command => 'rake test:isolated', 
        # :env => {
        #     'QUE_DATABASE_URL' => 'postgres://postgres:postgres@postgres/active_jobs_que_int_test',
        #     'QC_DATABASE_URL' => 'postgres://postgres:postgres@postgres/active_jobs_qc_int_test'
        # },
        # :services => [:redis, :beanstalkd, :postgres],
    },
    'activemodel' => {
        :dir => 'activemodel',
        :command => 'rake test',  
    },
    'activemodel isolated' => {
        :dir => 'activemodel',
        :command => 'rake test:isolated',  
    },
    'activerecord mysql2' => {
        :dir => 'activerecord',
        :services => [:mysql],
        :before_command => [
            run('sudo apt-get update'),
            install('default-libmysqlclient-dev', 'default-mysql-client'),
            setup_mysql(),
        ],
        :command => 'rake db:mysql:rebuild mysql2:test',  
    },
    'activerecord mysql2:isolated' => {
        :dir => 'activerecord',
        :services => [:mysql],
        :before_command => [
            run('sudo apt-get update'),
            install('default-libmysqlclient-dev', 'default-mysql-client'),
            setup_mysql(),
        ],
        :command => 'rake db:mysql:rebuild mysql2:isolated_test',
    },
    'activerecord postgresql' => {
        :dir => 'activerecord',
        :before_command => [
            run('sudo apt-get update'),
            install('postgresql-client')
        ],
        :services => [:postgres],
        :command => 'rake db:postgresql:rebuild postgresql:test',  
    },
    'activerecord postgresql:isolated' => {
        :dir => 'activerecord',
        :before_command => [
            run('sudo apt-get update'),
            install('postgresql-client')
        ],
        :services => [:postgres],
        :command => 'rake db:postgresql:rebuild postgresql:isolated_test',  
    },
    'activerecord sqlite3' => {
        :dir => 'activerecord',
        :before_command => [
            run('sudo apt-get update'),
            install('sqlite3')
        ],
        :command => 'rake sqlite3:test',  
    },
    'activerecord sqlite3:isolated' => {
        :dir => 'activerecord',
        :before_command => [
            run('sudo apt-get update'),
            install('sqlite3')
        ],
        :command => 'rake sqlite3:isolated_test',  
    },
    'activestorage' => {
        :dir => 'activestorage',
        :before_command => [
            run('sudo apt-get update'),
            run('sudo apt remove cmdtest'),
            run('sudo apt remove yarn'),
            install('sqlite3', 'ffmpeg', 'mupdf', 'mupdf-tools', 'poppler-utils'),
            install('nodejs-dev', 'node-gyp', 'libssl1.0-dev'),
            install('npm'),
            run('npm install -g yarn'),
            run('yarn -v'),
            run('yarn install'),
            run_in_dir('yarn install', 'actionview'),
        ],
        :command => 'rake test',  
    },
    'guides' => {
        :dir => 'guides',
        :command => 'rake test',  
    },
    'railties' => {
        :dir => 'railties',
        :services => [:postgres, :mysql],
        :before_command => [
            run('sudo apt-get update'),
            install('sqlite3'),
            install('default-libmysqlclient-dev', 'default-mysql-client'),
            setup_mysql(),
            run('sudo apt remove cmdtest'),
            run('sudo apt remove yarn'),
            install('nodejs-dev', 'node-gyp', 'libssl1.0-dev', 'ffmpeg'),
            install('npm'),
            run('npm install -g yarn'),
            run('yarn -v'),
            run('yarn install'),
            run_in_dir('yarn install', 'actionview'),
        ],
        :command => 'rake test',  
    },
 }

#  TESTS.delete_if {|key, value| !['activesupport isolated', 'activejob integration', 
#     'actionpack isolated','activejob isolated', 'activerecord mysql2', 'activerecord mysql2:isolated',
#     'activestorage'].include?(key) } # 
 
 TESTS.delete_if do |key, value| 
    [
        'activestorage', # Needs investigation, worked previously
        'guides', # Needs investigation, worked previously
        'railties', # Needs investigation
        'activejob integration', # Needs investigation
        'actioncable integration', # Requires SauceLabs
        'actionview ujs', # Requires Selenium or ?
    ].include?(key) 
 end 

 #TESTS.delete_if {|key, value| key != 'activerecord mysql2'} # 

 SERVICES = {
     :memcached => {
         :config => {
            'image' => 'memcached:latest',
            'ports' => ['11211:11211'],
            'options' => "--health-cmd \"timeout 5 bash -c 'cat < /dev/null > /dev/udp/127.0.0.1/11211'\" --health-interval 10s --health-timeout 5s --health-retries 5",
         },
        #  :env => {
        #     'MEMCACHE_SERVERS' => 'memcached:11211',
        #  },
     },
     :postgres => {
        :config => {
            'image' => 'postgres',
            'ports' => ['5432:5432'],
            'options' => "--health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5",
            'env' => {
                'POSTGRES_PASSWORD' => 'postgres',
            }
         },
         :env => {
            'POSTGRES_USER' => 'postgres',
            'POSTGRES_HOST' => 'localhost',
            'POSTGRES_PASSWORD' => 'postgres',
         },
     },
     :redis => {
        :config => {
            'image' => 'redis',
            'ports' => ['6379:6379'],
            'options' => '--health-cmd "redis-cli ping" --health-interval 10s --health-timeout 5s --health-retries 5',
        },
        :env => {
            # 'REDIS_URL' => 'redis://redis:6379/1',
           # 'REDIS_DRIVER' => 'ruby',
         },
     },
     :mysql => {
        :config => {
            'image' => 'mysql:latest',
            'ports' => ['3306:3306'],
            'env' => {
                'MYSQL_ROOT_PASSWORD' => 'password'
            },
            'options' => '--health-cmd="mysqladmin ping" --health-interval=10s --health-timeout=5s --health-retries=3',
        },
        :env => {
            'MYSQL_HOST' => '127.0.0.1'
         },
     },
     :beanstalkd => {
        :config => {
            'image' => 'schickling/beanstalkd',
            'ports' => ['11300:11300'],
            # 'options' => "--health-cmd \"timeout 5 bash -c 'cat < /dev/null > /dev/tcp/127.0.0.1/11300'\" --health-interval 10s --health-timeout 5s --health-retries 5",
        },
        # :env => {
        #     'BEANSTALK_URL' => 'beanstalk://beanstalkd',
        #  },
     },
 }

def services(services, env)
  services.inject({}) do | services, service|
    environment = SERVICES[service][:env]
    environment.each {|k,v|  env[k] = v } if environment
    services[service.to_s] = SERVICES[service][:config]
    services
  end
end

def test_jobs
    RUBY_VERSIONS.inject({}) do | jobs, (ruby_version, image_config)|
        
        TESTS.each do |test, config|
            env = image_config[:test_env] ? image_config[:test_env] : {}
            env = env.dup
            test_name = "#{test} (#{ruby_version} / #{OS})"
            steps = [
                uses('actions/checkout@master'),
                setup_ruby(ruby_version),
                run('bundle install'),
            ]
            steps += config[:before_command] if config[:before_command]
            steps << bundle_exec_dir(config[:command], config[:dir])
            job = {
                'name' => test_name,
                'runs-on' => OS,
                'needs' => normalize_key(bundle_job_name(ruby_version)),
                'steps' => steps,
            }
            job['services'] = services(config[:services], env) if config[:services]
            env.merge(config[:env]) if config[:env]
            job['env'] = env if !env.empty?
            jobs[normalize_key(test_name)] = job
        end
        jobs
    end
end

def bundle_exec_dir(command, dir)
    {
        'run' => "bundle exec #{command}",
        'working-directory' => dir,
    }
end

def uses(str)
  {'uses' => str}
end

def action_cache(os, ruby)
    {
        'uses' => 'actions/cache@v2',
        'with' => {
            'path' => 'vendor/bundle',
            'key' => "#{os}-#{ruby}-gems-${{hashFiles('**/Gemfile.lock')}}",
            'restore-keys' => "#{os}-#{ruby}-gems-"
        }
    }
end

hash = {
    'name' => 'Test Rails',
    'on' => 'push',
    'jobs' => generate_jobs()
}



jsonObj = hash.to_json
yaml = YAML.load(jsonObj)
print yaml.to_yaml
#puts YAML.dump hash