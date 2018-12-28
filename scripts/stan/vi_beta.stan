// varying intercept: beta
functions {

  matrix center_matrix(matrix x, int n) {
    // X_center = CX
    // where,
    // C = I - 1/n O
    // O = 11'
    real nr;
    matrix[n,n] I;
    matrix[n,n] O;
    matrix[n,n] C;
    nr = n;
    I = diag_matrix(rep_vector(1,n));
    O = tcrossprod(rep_matrix(1,n,1));
    C = I - O / n;
    return C * x;
  }

}
data {
  int<lower=0> N;		// observations
  int<lower=0> J;		// states
  int<lower=0> R;		// regions
  int<lower=1> K;		// first-level parameter number
  int<lower=1> L;		// second-level parameter number
  vector[N] y;			// outcomes
  matrix[N,K] x;		// first-level predictors
  matrix[J,L] z;		// second-level predictors
  int state[N];			// state indicators (at first level)
  int region[J];		// region indicators (at second level)
}
transformed data {
  matrix[N,K] xc;
  matrix[N,K] Q_ast_1;
  matrix[K,K] R_ast_1;
  matrix[K,K] R_ast_1_inverse;

  matrix[J,L] zc;
  matrix[J,L] Q_ast_2;
  matrix[L,L] R_ast_2;
  matrix[L,L] R_ast_2_inverse;

  // center the predictor matrix
  xc = center_matrix(x, N);
  zc = center_matrix(z, J);

  // thin and scale the QR decomposition
  Q_ast_1 = qr_Q(xc)[, 1:K] * sqrt(N - 1);
  R_ast_1 = qr_R(xc)[1:K, ] / sqrt(N - 1);
  R_ast_1_inverse = inverse(R_ast_1);

  Q_ast_2 = qr_Q(zc)[, 1:L] * sqrt(J - 1);
  R_ast_2 = qr_R(zc)[1:L, ] / sqrt(J - 1);
  R_ast_2_inverse = inverse(R_ast_2);
}
parameters {
  vector[R] a_region;    // vector of second-level intercepts
  vector[J] a_state;     // vector of first-level intercepts
  vector[L] theta_2;     // coefficients on Q_ast_2
  vector[K] theta_1;     // coefficients on Q_ast_1
  real<lower=0> sigma;   // error scale for intercept
  real<lower=0> phi;	 // dispersion parameter
}
model {
  vector[N] mu;

  // prior on region
  a_region ~ normal(0,5);

  // model intercepts
  a_state ~ normal(Q_ast_2 * theta_2 + a_region[region], sigma);

  // linear combination
  mu = inv_logit(Q_ast_1 * theta_1 + a_state[state]);

  // likelihood
  y ~ beta(mu * phi, (1.0 - mu) * phi);
}
generated quantities {
  vector[K] beta;
  vector[L] gamma;
  beta = R_ast_1_inverse * theta_1; // coefficients on x
  gamma = R_ast_2_inverse * theta_2; // coefficients on z
}

