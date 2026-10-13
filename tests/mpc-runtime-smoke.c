#include <mpc.h>
#include <string.h>

int main(void) {
    if (strcmp(mpc_get_version(), "1.3.1")) return 1;
    mpc_t value, result;
    mpc_init2(value, 256);
    mpc_init2(result, 256);
    mpc_set_si_si(value, 3, 4, MPC_RNDNN);
    mpc_mul(result, value, value, MPC_RNDNN);
    if (mpfr_cmp_si(mpc_realref(result), -7) || mpfr_cmp_si(mpc_imagref(result), 24)) return 2;
    mpfr_t absolute;
    mpfr_init2(absolute, 256);
    mpc_abs(absolute, value, MPFR_RNDN);
    if (mpfr_cmp_ui(absolute, 5)) return 3;
    mpc_conj(result, value, MPC_RNDNN);
    if (mpfr_cmp_si(mpc_realref(result), 3) || mpfr_cmp_si(mpc_imagref(result), -4)) return 4;
    mpc_set_si_si(value, -1, 0, MPC_RNDNN);
    mpc_sqrt(result, value, MPC_RNDNN);
    if (!mpfr_zero_p(mpc_realref(result)) || mpfr_cmp_ui(mpc_imagref(result), 1)) return 5;
    mpfr_clear(absolute);
    mpc_clear(value);
    mpc_clear(result);
    mpfr_free_cache();
    return 0;
}
