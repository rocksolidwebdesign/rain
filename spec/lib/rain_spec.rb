require 'spec_helper'

describe "rain" do
  before(:all) do
    @instances = Flower.all
    @features  = [:sepal_len, :sepal_wid, :petal_len, :petal_wid]

    @discretizer = Rain::Discretizer.new(@instances, @features)
  end

  context "discretizer" do
    it "can create equal-width cut points" do
      correct_cutpoints = {
        sepal_len: [5.2,6.1,7.0],
        sepal_wid: [2.6,3.2,3.8],
        petal_len: [1.9,3.9,5.4],
        petal_wid: [0.6,1.3,1.9]
      }

      # this is basically an arbirary number of bins
      num_bins = 4

      # we need to fit the cut points to the actual
      # data in order to pass the test using the
      # bin values from Iris
      @discretizer.make_cutpoints_equalwidth_fit!(num_bins)
      @discretizer.feature_cut_points.should == correct_cutpoints
    end

    it "can create equal-length cut points" do
      # put an equal number of instances in each bin
      correct_cutpoints = {
        sepal_len: [5.1,5.8,6.4],
        sepal_wid: [2.8,3.0,3.3],
        petal_len: [1.6,4.4,5.1],
        petal_wid: [0.3,1.3,1.8]
      }

      # this is basically an arbirary number of bins
      num_bins = 4

      @discretizer.make_cutpoints_equallength!(num_bins)
      @discretizer.feature_cut_points.should == correct_cutpoints
    end

    #it "can create bayesian cut points" do
    #  1.should == 1
    #end

    #it "can create 1-rule cut points" do
    #  1.should == 1
    #end

    it "can create entropy cut points" do
      # put an equal number of instances in each bin
      correct_cutpoints = {
        sepal_len: [5.4,6.1],
        sepal_wid: [4.4],
        petal_len: [1.9,4.9,6.9],
        petal_wid: [0.6,1.6,2.5]
      }

      # this is basically an arbirary number of bins
      feature_sets = {
        :sepal_len => Flower.select('sepal_len AS value, classification').order(:sepal_len),
        :sepal_wid => Flower.select('sepal_wid AS value, classification').order(:sepal_wid),
        :petal_len => Flower.select('petal_len AS value, classification').order(:petal_len),
        :petal_wid => Flower.select('petal_wid AS value, classification').order(:petal_wid)
      }

      results = @discretizer.make_cutpoints_mdlp(feature_sets[:sepal_len])

      puts "Cutpoint index results: #{results}"
      results.should == correct_cutpoints[:sepal_len]
    end
  end
end
