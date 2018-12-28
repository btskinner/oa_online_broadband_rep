// single level: normal
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
  int<lower=0> K;		// predictors
  matrix[N, K] x;		// predictor matrix
  vector[N] y;			// outcomes
}
transformed data {
  matrix[N,K] xc;
  matrix[N,K] Q_ast;
  matrix[K,K] R_ast;
  matrix[K,K] R_ast_inverse;

  // center the predictor matrix
  xc = center_matrix(x, N);

  // thin and scale the QR decomposition
  Q_ast = qr_Q(xc)[, 1:K] * sqrt(N - 1);
  R_ast = qr_R(xc)[1:K, ] / sqrt(N - 1);
  R_ast_inverse = inverse(R_ast);
}
parameters {
  real alpha;           // intercept
  vector[K] theta;      // coefficients on Q_ast
  real<lower=0> sigma;  // error scale
}
model {
  y ~ normal(Q_ast * theta + alpha, sigma);  // likelihood
}
generated quantities {
  vector[K] beta;
  beta = R_ast_inverse * theta; // coefficients on x
}
