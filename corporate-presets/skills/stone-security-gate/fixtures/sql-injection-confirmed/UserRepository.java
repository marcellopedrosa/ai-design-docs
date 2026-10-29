// Exemplo sintético de SQL Injection confirmado via concatenação direta
public List<User> searchUsers(String query) {
    String sql = "SELECT * FROM users WHERE name = '" + query + "'";
    return entityManager.createNativeQuery(sql, User.class).getResultList();
}
