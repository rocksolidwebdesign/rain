# Rain

NOTE: this library is not even close to usable yet - I will remove this warning when it's actually got some useful things in it

a Ruby library for Adaptive machine learning and Intelligent classification systems such as Neural Networks

## Discretizers

Current Support

* Splitting
  - Unsupervised
    * Binning
      - Equal Width

Planned Support

* Splitting
  - Unsupervised
    * Binning
      - Equal Width
      - Equal Length
      - Bayesian i.e. K-means
  - Supervised
    * Entropy
      - ID3
      - D2
      - MDLP
      - Contrast
      - Mantaras
      - Distance
    * Binning
      - 1-rule
    * Dependency
      - Zeta
    * Accuracy
      - Adaptive
      - Quantizer
* Merging
  - Supervised
    * Dependency
      - ChiMerge
      - Chi2
      - ConMerge

## Machine Learning and Artificial Intelligence

Ideally this library will support the following predictive learning algorithms:

* Naive Bayesian

Ideally this library will support the following machine learning algorithms:

* Genetic Algorithm
* Neural Network

## For Developers

You can run the tests like this

    rspec

That is all
