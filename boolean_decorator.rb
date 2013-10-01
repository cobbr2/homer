#
# This provides listable decorations within a class hierarchy.
#
# I.e., in addition to the normal cloudcrowd decoration utility, this allows a
# base class to define a set of decorations it's interested in, and then be
# able to list all its subclasses that are decorated that way.
#
module BooleanDecoration
    def self.decorations
        @@decorations ||= {}
    end

    def self.boolean_decoration(name,value = true)
        self.send(:decorate,name,value)
        unless decorations[name]
            decorations[name] = Set.new
            pluralized = name.to_s.pluralize
            instance_eval %Q{
                    def #{pluralized}
                        return decorations[:#{name}]
                    end

                    def all_#{pluralized}
                        return self.all({:discriminator => #{pluralized}})
                    end

                    def #{name}?
                        return #{name}
                    end
                }
        end
        if value
            decorations[name] << self
        else
            decorations[name].delete(self)
        end
    end

    # Every job decoration that you want to query has
    # to be defined false in the base class so the method
    # gets constructed
    job_decoration :composer,false
    job_decoration :decomposer,false
    job_decoration :clone_inputs,false
end

class Food < Foo
    job_decoration :composer,true
end
