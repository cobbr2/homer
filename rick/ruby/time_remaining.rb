# Usage:
#   > est = Tm.new(20000) { Covered.where(:sponsor_id => 1).count }
#   wait some time
#   >   est.estimate
#   => [Wed, 21 May 2014 15:00:51 PDT -07:00, Wed, 21 May 2014 15:00:51 PDT -07:00]
#   wait some more
#   > est.estimate
#   => [Wed, 21 May 2014 15:00:58 PDT -07:00, Wed, 21 May 2014 15:00:54 PDT -07:00]
#
# The two times returned are likely to be upper and lower bounds; they're
# calculated based on the short term (most recent) samples vs. the longest term
# (least recent) sample.
class Tm

  class Fail < Exception ; end

  attr_accessor :samples, :target, :sampler, :long_term_rate, :short_term_rate

  def initialize(target, &block)
    self.target = target
    self.sampler = block
    self.samples = []
    sample
  end

  def to_s
    { last_sample: samples.last, samples: samples.count, long_term_rate: long_term_rate, short_term_rate: short_term_rate, units: 'per second' }.as_json.to_json
  end

  def sample
    sample = {
        t: Time.now,
        v: sampler.call
      }
    self.long_term_rate = rate(sample, samples.first)
    self.short_term_rate = rate(sample, samples.last)

    self.samples << sample
  end

  def rate(sample, referent)
    return nil unless referent

    dx = sample[:v] - referent[:v]
    dt = sample[:t] - referent[:t]

    raise Tm::Fail.new('No change in time') unless dt != 0

    rate = dx.to_f / dt.to_f
  end

  def remaining(rate = self.short_term_rate)
    raise Tm::Fail.new('Not enough samples') unless rate
    raise Tm::Fail.new('No change in value') unless rate != 0
    (target - samples.last[:v]) / rate
  end

  def estimate
    sample
    [remaining, remaining(self.long_term_rate)].map {|x| x.seconds.from_now.in_time_zone('America/Los_Angeles')}
  rescue Tm::Fail => e
    puts e.message
  end

end
