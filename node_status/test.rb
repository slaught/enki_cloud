#!/usr/bin/ruby

require 'test/unit'
require 'yaml'

# ========= modify these to suit your environment =============
WORKING_SERVICE={
  'Service Type' => 'status',
  'Cluster Name' => 'web_fe2',
  'IP Address' => '10.10.10.51',
  'HA Port' => 80,
  'HA Proto' => 'tcp',
  'Forward Mark' => 2130709505,
  'Check URL' => 'http://localhost:9999'
}
WORKING_SERVICE_2={
  'Service Type' => 'status',
  'Cluster Name' => 'web_fe',
  'IP Address' => '10.60.16.60',
  'HA Port' => 80,
  'HA Proto' => 'tcp',
  'Forward Mark' => 2130711553,
  'Check URL' => 'http://localhost:9998'
}
BAD_SERVICE_2={
  'Service Type' => 'status',
  'Cluster Name' => 'web_fe2',
  'IP Address' => '10.10.10.51',
  'HA Port' => 80,
  'HA Proto' => 'tcp',
  'Forward Mark' => 2130709505,
  'Check URL' => 'http://localhost:9991'
}
BAD_SERVICE={
  'Service Type' => 'status',
  'Cluster Name' => 'web_fe',
  'IP Address' => '10.60.16.60',
  'HA Port' => 80,
  'HA Proto' => 'tcp',
  'Forward Mark' => 2130711553,
  'Check URL' => 'http://localhost:9990'
}
WORKING_STATE={
  'Service Type' => 'state',
  'Cluster Name' => 'web_fe2',
  'Forward Mark' => 2130709505,
  'Check URL' => 'http://localhost:9999'
}
BAD_STATE={
  'Service Type' => 'state',
  'Cluster Name' => 'web_fe',
  'Forward Mark' => 2130711553,
  'Check URL' => 'http://localhost:9990'
}
BAD_STATE_2={
  'Service Type' => 'state',
  'Cluster Name' => 'web_fe2',
  'Forward Mark' => 2130709505,
  'Check URL' => 'http://localhost:9990'
}
# WORKING_SERVICE_LINE='web_fe2    10.10.10.51:80/tcp    2130709505    http://localhost:9999'
# WORKING_SERVICE_LINE_2='web_fe    10.60.16.60:80/tcp    2130711553    http://localhost:9998'
# BAD_SERVICE_LINE='web_fe    10.60.16.60:80/tcp    2130711553    http://localhost:9990'
# BAD_SERVICE_LINE_2='web_fe2    10.10.10.51:80/tcp    2130709505    http://localhost:9991'
COMMENT_LINE='### web_fe    10.60.16.60:80/tcp    2130711553    http://localhost:9990'

WORKING_SERVICE_LINE_OLD='http://localhost:9999'
WORKING_SERVICE_LINE_OLD_2='http://localhost:9998'
BAD_SERVICE_LINE_OLD='http://localhost:9990'
BAD_SERVICE_LINE_OLD_2='http://localhost:9991'
SMTP_LINE='smtp://localhost:25'

WORKING_CODE_DIR='/home/user/Code/enki_node_status'
# ======== ENKI status constants =================
APP_DOWN_PATH='/enki/var/run'
SERVICE_DOWN_PATH='/enki/var/tmp/services'
SERVICE_CHECKS_PATH='/etc/enki/configs/node/service.checks'
# =======================================

def main
  if ARGV[0] == '--clear'
    clear_files
    exit
  elsif ARGV[0] == '--make=2good'
    write_service_checks [WORKING_SERVICE, WORKING_SERVICE_2]
    exit
  elsif ARGV[0] == '--make=1good1bad'
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    exit
  elsif ARGV[0] == '--make=1good1badold'
    write_old_service_checks [WORKING_SERVICE_LINE_OLD, BAD_SERVICE_LINE_OLD]
    exit
  elsif ARGV[0] == '--hack'   # put whatever state you now want to check in here...
    clear_files
    write_service_checks [WORKING_STATE, BAD_SERVICE_2]
    exit
  else
    # copy files from working code dir to installation dir and restart nginx
    %x[sudo cp #{WORKING_CODE_DIR}/enki-status.conf /etc/nginx/sites-enabled/enki-status]
    %x[sudo cp #{WORKING_CODE_DIR}/perl/ENKI.pm /usr/local/nginx/perl/ENKI.pm]
    %x[sudo cp #{WORKING_CODE_DIR}/perl/ENKI/Status.pm /usr/local/nginx/perl/ENKI/Status.pm]
    %x[sudo cp #{WORKING_CODE_DIR}/perl/LWP/Protocol/smtp.pm /usr/local/nginx/perl/LWP/Protocol/smtp.pm]
    out = %x[sudo /etc/init.d/nginx restart]
    puts out
    clear_files
    # tests will start now ...
  end
end

def write_service_checks(services)
  File.open(SERVICE_CHECKS_PATH, 'w'){ |f|
    f.write COMMENT_LINE+"\n"
    f.write services.to_yaml
  }
end

def write_old_service_checks(lines)
  File.open(SERVICE_CHECKS_PATH, 'w'){ |f|
    lines.each{ |line|
      f.write "#{line}\n"
    }
    f.write COMMENT_LINE
  }
end

def assert_response_and_health(url_tail, expected_status, no_curl=false)
  output = get_response url_tail, expected_status, no_curl
  assert_health_output output
  output
end
def assert_response_and_no_health(url_tail, expected_status, no_curl=false)
  output = get_response url_tail, expected_status, no_curl
  assert_no_health_output output
  output
end

def get_response(url_tail, expected_status, no_curl=false)
  case expected_status
    when 200
      check_string = '200 OK'
    when 404
      check_string = '404 Not Found'
    when 503
      check_string = '503 Service Temporarily Unavailable'
    else
      check_string = ''
  end
  if not no_curl
    output = %x[curl -i localhost/#{url_tail}]
    assert output.include? check_string
  end
  output = %x[GET -s localhost/#{url_tail}]
  assert output.include? check_string
  output
end

def assert_health_output(output)
  assert output.include? 'Health'
  assert output.include? 'Load'
  assert output.include? 'Memory'
end
def assert_no_health_output(output)
  assert ! output.include?('Health')
  assert ! output.include?('Load')
  assert ! output.include?('Memory')
end

def assert_service_downfile_line(output, cluster_name, filename)
  assert output.include? "Comment: #{cluster_name} service is marked as down by local file: '#{filename}'"
end

def assert_no_service_downfile_line(output, cluster_name, filename)
  assert ! output.include?("Comment: #{cluster_name} service is marked as down by local file: '#{filename}'")
end

def clear_files
  %x[sudo rm #{SERVICE_CHECKS_PATH}] if File.exist?(SERVICE_CHECKS_PATH)
  %x[sudo rm #{SERVICE_CHECKS_PATH}.temp] if File.exist?("#{SERVICE_CHECKS_PATH}.temp")
  %x[sudo rm /Down] if File.exist?('/Down')
  %x[sudo rm #{APP_DOWN_PATH}/Down] if File.exist?("#{APP_DOWN_PATH}/Down")
  Dir.foreach("#{SERVICE_DOWN_PATH}") { |f|
    %x[sudo rm #{SERVICE_DOWN_PATH}/#{f}] if f =~ /down$/i
  }
end

class CnuStatusTest < Test::Unit::TestCase

### Gives wrong behavior for some reason
  # def setup
    # clear_files
  # end
  # def teardown
    # clear_files
  # end

# ============= /services =====================
  def test_service_list
    lines = [WORKING_SERVICE, WORKING_STATE, BAD_SERVICE]
    write_service_checks lines
    output = get_response 'services', 200
    assert output.include? lines.to_yaml
  end

  def test_service_list_old
    lines = [WORKING_SERVICE_LINE_OLD, BAD_SERVICE_LINE_OLD]
    write_old_service_checks lines
    output = get_response 'services', 200
    lines.each{ |line|
      assert output.include? line
    }
  end

  def test_service_list_no_service_checks_file
    lines = [WORKING_SERVICE, BAD_SERVICE]
    write_service_checks lines
    %x[sudo mv #{SERVICE_CHECKS_PATH} #{SERVICE_CHECKS_PATH}.temp]
    output = get_response 'services', 404
    # lines.each{ |line|
      assert ! output.include?(lines.to_yaml)
    # }
    %x[sudo mv #{SERVICE_CHECKS_PATH}.temp #{SERVICE_CHECKS_PATH}]
  end

  def test_service_list_chmod000
    lines = [WORKING_SERVICE, BAD_SERVICE]
    write_service_checks lines
    %x[sudo chmod 000 #{SERVICE_CHECKS_PATH}]
    output = get_response 'services', 404
    # lines.each{ |line|
      assert ! output.include?(lines.to_yaml)
    # }
    %x[sudo chmod 644 #{SERVICE_CHECKS_PATH}]
  end

  def test_service_list_empty_service_checks_file
    write_service_checks []
    get_response 'services', 200
  end
# ======================================

# ============= /status ================
  def test_status_no_service_checks_file
    lines = [WORKING_SERVICE]
    write_service_checks lines
    %x[sudo mv #{SERVICE_CHECKS_PATH} #{SERVICE_CHECKS_PATH}.temp]
    assert_response_and_health 'status', 200
    %x[sudo mv #{SERVICE_CHECKS_PATH}.temp #{SERVICE_CHECKS_PATH}]
  end

  def test_status_both_up
    lines = [WORKING_SERVICE, WORKING_SERVICE_2]
    write_service_checks lines
    output = get_response 'status', 200
    write_service_checks (lines << BAD_STATE)
    output = get_response 'status', 200
  end

  def test_status_one_down
    lines = [WORKING_SERVICE, BAD_SERVICE]
    write_service_checks lines
    output = get_response 'status', 503
  end

  def test_status_old_both_up
    lines = [WORKING_SERVICE_LINE_OLD, WORKING_SERVICE_LINE_OLD_2]
    write_old_service_checks lines
    output = get_response 'status', 200
  end

  def test_status_old_one_down
    lines = [WORKING_SERVICE_LINE_OLD, BAD_SERVICE_LINE_OLD]
    write_old_service_checks lines
    output = get_response 'status', 503
  end

  def test_status_only_states
    lines = [WORKING_STATE, BAD_STATE]
    write_service_checks lines
    output = get_response 'status', 200
  end
# =====================================

# ========= /status/service/<query> ===============
  def test_fwmark
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/fwm=2130709505', 200
    get_response 'status/service/fwm=2130711553', 503
  end

  def test_fwmark_with_state
    write_service_checks [WORKING_SERVICE_2, WORKING_STATE]
    assert_response_and_health 'status/service/fwm=2130711553', 200
    write_service_checks [WORKING_SERVICE_2, BAD_STATE]
    output = get_response 'status/service/fwm=2130711553', 503
    assert output.include?(BAD_STATE['Check URL'])
  end

  def test_ip
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/10.10.10.51', 200
    get_response 'status/service/10.60.16.60', 503
  end

  def test_ip_partial
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/10.11', 200
    assert_response_and_health 'status/service/10.', 200
    get_response 'status/service/10', 404
    get_response 'status/service/38.106', 503
    get_response 'status/service/38.', 503
  end

  def test_ip_port
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/10.10.10.51:80', 200
    get_response 'status/service/10.60.16.60:80', 503
  end

  def test_port_proto
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    get_response 'status/service/80/tcp', 503
    write_service_checks [WORKING_SERVICE, WORKING_SERVICE_2]
    get_response 'status/service/80/tcp', 200
  end

  def test_cluster_name
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/web_fe2', 200
    get_response 'status/service/web_fe', 503
  end

  def test_cluster_name_partial
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/web', 200
    get_response 'status/service/notweb', 503
  end

  def test_full_query
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    assert_response_and_health 'status/service/10.10.10.51:80/tcp/fwm=2130709505/web_fe2', 200
    get_response 'status/service/10.10.10.51:80/tcp/fwm=2130709505/web_fe2xxx', 404
    get_response 'status/service/10.60.16.60:80/tcp/fwm=2130711553/web_fe', 503
  end

  def test_query_no_match
    write_service_checks [WORKING_SERVICE, BAD_SERVICE]
    get_response 'status/service/127.0.0.1', 404
  end

  def test_query_no_service_checks_file
    lines = [WORKING_SERVICE]
    write_service_checks lines
    %x[sudo mv #{SERVICE_CHECKS_PATH} #{SERVICE_CHECKS_PATH}.temp]
    output = get_response 'status/service/10.10.10.51:80', 404
    # lines.each{ |line|
      assert ! output.include?(lines.to_yaml)
    # }
    %x[sudo mv #{SERVICE_CHECKS_PATH}.temp #{SERVICE_CHECKS_PATH}]
  end

# ================================================

# ============== test downfiles ==========================
  def test_status_root_node_down
    %x[sudo touch /Down]
    assert_response_and_health 'status', 503
    %x[sudo rm /Down]
  end

  def test_status_app_path_node_down
    %x[sudo touch #{APP_DOWN_PATH}/Down]
    assert_response_and_health 'status', 503
    %x[sudo rm #{APP_DOWN_PATH}/Down]
  end

  def test_status_one_service_downfile
    lines = [WORKING_SERVICE, WORKING_SERVICE_2]
    write_service_checks lines
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    output = assert_response_and_health 'status', 503
    assert_service_downfile_line output, WORKING_SERVICE['Cluster Name'], filename 
    %x[sudo rm #{filename}]
  end

  def test_services_one_service_downfile
    lines = [WORKING_SERVICE, WORKING_SERVICE_2]
    write_service_checks lines
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    output = get_response 'services', 200
    assert output.include? lines.to_yaml
    %x[sudo rm #{filename}]
  end

  ### with query #####################
  def test_fwmark_checked_service_downfile
    write_service_checks [WORKING_SERVICE, WORKING_SERVICE_2]
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    output = assert_response_and_health "status/service/fwm=#{WORKING_SERVICE['Forward Mark']}", 503
    assert_service_downfile_line output, WORKING_SERVICE['Cluster Name'], filename 
    %x[sudo rm #{filename}]
  end

  def test_fwmark_checked_service_no_downfile
    write_service_checks [WORKING_SERVICE, WORKING_SERVICE_2]
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    assert_response_and_health "status/service/fwm=#{WORKING_SERVICE_2['Forward Mark']}", 200
    %x[sudo rm #{filename}]
  end

  def test_match_both_one_service_downfile
    write_service_checks [WORKING_SERVICE, WORKING_SERVICE_2]
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    output = assert_response_and_health "status/service/tcp", 503
    assert_service_downfile_line output, WORKING_SERVICE['Cluster Name'], filename 
    %x[sudo rm #{filename}]
  end

# ======== health =======================
  def test_health
    lines = [WORKING_SERVICE, WORKING_SERVICE_2]
    write_service_checks lines
    output = assert_response_and_health 'status/health', 200
  end

  def test_health_one_down
    lines = [WORKING_SERVICE, BAD_SERVICE]
    write_service_checks lines
    output = assert_response_and_health 'status/health', 200
    assert ! output.include?(lines.to_yaml)
  end

  def test_health_one_service_downfile
    lines = [WORKING_SERVICE, WORKING_SERVICE_2]
    write_service_checks lines
    filename = "#{SERVICE_DOWN_PATH}/#{WORKING_SERVICE['Cluster Name']}_Down"
    %x[sudo touch #{filename}]
    output = assert_response_and_health 'status/health', 200
    assert_no_service_downfile_line output, WORKING_SERVICE['Cluster Name'], filename 
    %x[sudo rm #{filename}]
  end

  def test_health_root_node_down
    %x[sudo touch /Down]
    assert_response_and_health 'status/health', 503
    %x[sudo rm /Down]
  end

  def test_health_app_path_node_down
    %x[sudo touch #{APP_DOWN_PATH}/Down]
    assert_response_and_health 'status/health', 503
    %x[sudo rm #{APP_DOWN_PATH}/Down]
  end

# =========== state =======================
  def test_state_simple
    write_service_checks [WORKING_STATE]
    assert_response_and_no_health 'state/service/fwm=2130709505', 200
  end

  def test_state_service_down
    write_service_checks [WORKING_STATE, BAD_SERVICE_2]
    assert_response_and_no_health 'state/service/fwm=2130709505', 200
  end

  def test_state_state_down
    write_service_checks [WORKING_STATE, BAD_STATE_2]
    assert_response_and_no_health 'state/service/fwm=2130709505', 503
  end

# ========== SMTP checks ====================
  def test_status_smtp
    write_old_service_checks [SMTP_LINE]
    assert_response_and_health 'status', 200, true
  end

end

main()
