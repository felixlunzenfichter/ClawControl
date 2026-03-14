function createGatewayClient({ connectImpl } = {}) {
  return {
    async connect() {
      if (connectImpl) return connectImpl();
      return { ok: true };
    }
  };
}

module.exports = { createGatewayClient };
