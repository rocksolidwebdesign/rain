class Flower < ActiveRecord::Base
end

# Formula Chromosome {{{
class FormulaChromosome < Rain::GA::Chromosome
  def initialize(options={}, bitstring=nil)
    super

    @target_solution = options[:target_solution] unless options[:target_solution].nil?
  end

  def to_s
    "#{encoded}\t#{decoded} = #{result.to_s.ljust(17, '0')}\t$: #{fitness.to_s.ljust(17, '0')}\t%: #{probability}"
  end

  def is_solution
    @target_solution == result
  end

  def valid?
    s = decoded

    # number -> operator -> number -> operator -> number
    div_zero = /\/0/

      # it doesn't try to divide by zero, i.e. matched divide by zero is nil
      no_div_by_zero = s.match(div_zero).nil?

    super && no_div_by_zero
  end

  def fitness
    return nil unless valid?

    # put some reasonable bounds on it
    max_fitness  = 1.999
    max_distance = 15

    # filter/bound unfit results where the distance
    # from the solution is too large
    distance = (@target_solution - result).abs
    if distance > max_distance
      distance = max_distance
    end

    # a distance of zero from the solution
    # means that this is a solution
    if distance == 0
      # prevent dividing by zero
      fitness = 2
    else
      fitness = 1.to_f/distance.to_f

      # filter/bound the fitness to prevent
      # overfitting the results
      if fitness > max_fitness
        fitness = max_fitness
      end
    end

    fitness
  end

  protected
  def result
    formula = decoded.gsub(/([0-9])/, ' \1.to_f ')
    eval(formula)
  end
end
# }}}

# FormulaPool {{{
class FormulaPool < Rain::GA::Pool
  def initialize(options={})
    super

    @total_solutions = []

    @chromosome_class = FormulaChromosome
    @chromosome_settings.merge!(
      :target_solution => options[:target_solution]
    )
  end

  def solutions
    @chromosomes.select(&:is_solution)
  end

  def evolve!
    super

    @total_solutions += solutions
  end
end
# }}}
