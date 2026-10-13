#include <Eigen/Dense>
#include <Eigen/Eigenvalues>
#include <cmath>
#include <cstdio>

int main()
{
    Eigen::Matrix2d matrix;
    matrix << 4.0, 1.0, 1.0, 3.0;
    const Eigen::Vector2d rhs(1.0, 2.0);
    const Eigen::Vector2d solution = matrix.ldlt().solve(rhs);
    if ((matrix * solution - rhs).norm() > 1e-12)
        return 1;
    Eigen::SelfAdjointEigenSolver<Eigen::Matrix2d> eigen(matrix);
    if (eigen.info() != Eigen::Success ||
        std::abs(eigen.eigenvalues().sum() - matrix.trace()) > 1e-12)
        return 2;
    std::puts("Eigen target consumer: PASS linear solve and symmetric eigenvalues");
    return 0;
}
