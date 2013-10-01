
def command(system_str, kill_system_string = "kill", &block)
    if pid = fork
        yield
        system("#{kill_system_string} #{pid}")
        done = nil
        Timeout::timeout(1) { done = waitpid(pid, 0) }
        unless done 
            system("{kill_system_string} -9 #{pid}")
            Timeout::timeout(1) { done = waitpid(pid, 0) }
        end
        done.should_not be_nil
    else
        system(system_str)
    end
end
