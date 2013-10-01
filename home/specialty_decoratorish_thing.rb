
class Foo
    def self.specialties
        @@specialties ||= {}
    end

    def self.specialty(policy, value = true)
        unless specialties[policy]
            specialties[policy] = []

            self.instance_eval %Q{
                    def #{policy}s
                        return specialties[:#{policy}]
                    end

                    def #{policy}?
                        return #{policy}s.member?(self)
                    end
                }
        end

        if value && !specialties[policy].member?(self)
            specialties[policy].push(self)
        end
        unless value
            specialties[policy].delete(self)
        end
        puts "specialties[#{policy}] = #{specialties[policy]}"
    end

    # place holder for dynamically defined accessors
    def self.policy(policy)
        return specialties[policy]
    end

    specialty(:composer, false)
    specialty(:decomposer, false)
    specialty(:clone_input, false)
end

class Food < Foo
    specialty :composer
end
